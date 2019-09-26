import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:args/command_runner.dart';
import 'package:dart_up/src/models.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pretty_logging/pretty_logging.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class ServeCommand extends Command {
  @override
  String get name => 'serve';

  @override
  String get description =>
      'Launch an HTTP server that manages other Dart applications.';

  ServeCommand() {
    argParser
      ..addFlag('managed',
          negatable: false,
          help: 'Mute logging, and just print out the port number.')
      ..addFlag('require-password',
          negatable: false,
          help:
              'Always require a password, even for connections from localhost.')
      ..addFlag('x-forwarded-for',
          defaultsTo: true,
          help:
              'Honor the `x-forwarded-for` header when checking user IP addresses.')
      ..addOption('address',
          abbr: 'a', defaultsTo: '127.0.0.1', help: 'The address to listen at.')
      ..addOption('port',
          abbr: 'p', defaultsTo: '2374', help: 'The port to listen to.')
      ..addOption('pub-path', help: 'The path to `pub`.');
  }

  run() async {
    hierarchicalLoggingEnabled = true;

    var isManaged = argResults['managed'] as bool;
    var logger = Logger('dart_up');
    String pubPath;

    if (argResults.wasParsed('pub-path')) {
      pubPath = argResults['pub-path'] as String;
    } else {
      var binDir = p.dirname(Platform.resolvedExecutable);
      pubPath = p.join(binDir, (Platform.isWindows ? 'pub.bat' : 'pub'));
    }

    if (!isManaged) logger.onRecord.listen(prettyLog);

    var app = Angel(logger: logger), http = AngelHttp(app);
    app.errorHandler = (e, req, res) => e;

    // Load the existing dart_up dir + config, etc.
    var dartUpDir = DartUpDirectory.dartTool();
    await dartUpDir.initialize();

    // Spawn every app we have saved.
    var apps = <String, Application>{};
    await for (var appDir in dartUpDir.appsDir.findApps()) {
      apps[appDir.name] = await appDir.spawn();
    }

    // Helpers
    Future<String> getNameFromBody(RequestContext req) async {
      var body = await req.parseBody().then((_) => req.bodyAsMap);
      if (!body.containsKey('name')) {
        throw FormatException('Missing "name" in body.');
      }

      return body['name'] as String;
    }

    Future<Application> getApplicationFromBody(RequestContext req) async {
      var name = await getNameFromBody(req);
      if (!apps.containsKey(name)) {
        throw AngelHttpException.notFound(
            message: 'No application named "$name" exists.');
      }
      return apps[name];
    }

    // Routes

    // Authentication middleware
    Future<bool> enforceAuth(RequestContext req, ResponseContext res) async {
      // If the admin said, "always require a password," then ALWAYS require it
      // for administrative actions.
      var requiresPassword = argResults['require-password'] as bool;
      if (!requiresPassword) {
        // Otherwise, only require the password if the user is NOT '127.0.0.1'
        // (or the IPv6 equivalent).
        //
        // By default, honor the `x-forwarded-for` header (i.e. via nginx). But
        // this can be disabled, in a case where the header's integrity cannot be
        // verified.
        var ip = req.ip;
        if (argResults['x-forwarded-for'] as bool) {
          ip = req.headers.value('x-forwarded-for') ?? ip;
        }
        requiresPassword = ip != InternetAddress.loopbackIPv4.address &&
            ip != InternetAddress.loopbackIPv6.address;
      }

      // If no password is required, pass through.
      if (!requiresPassword) return true;

      var wwwAuthenticate =
          'Basic realm="Username and password are required.", charset="UTF-8"';

      // Otherwise, try to perform Basic authentication.
      var authHeader = req.headers.value('authorization');
      if (authHeader == null || !authHeader.startsWith('Basic ')) {
        res.headers['www-authenticate'] = wwwAuthenticate;
        throw AngelHttpException.notAuthenticated(
            message: 'Basic authentication is required.');
      }

      // Decode the username and password
      var encoded = authHeader.substring(6);
      var authString = utf8.decode(base64Url.decode(encoded));
      var authParts = authString
          .split(':')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (authParts.length != 2) {
        throw FormatException('Invalid Basic authentication header.');
      }

      if (!await dartUpDir.passwordFile.verify(authParts[0], authParts[1])) {
        res.headers['www-authenticate'] = wwwAuthenticate;
        throw AngelHttpException.notAuthenticated(
            message: 'Invalid username or password.');
      }
      return true;
    }

    var protectedRouter = app.chain([enforceAuth]);

    protectedRouter.get('/list', (req, res) => apps);

    protectedRouter.post('/kill', (req, res) async {
      var app = await getApplicationFromBody(req);
      await app.kill();
      return app;
    });

    protectedRouter.post('/start', (req, res) async {
      var app = await getApplicationFromBody(req);
      if (!app.isDead) {
        return app;
      } else {
        var appDir = await dartUpDir.appsDir.create(app.name);
        return apps[app.name] = await appDir.spawn();
      }
    });

    protectedRouter.post('/remove', (req, res) async {
      // Kill the app.
      var app = await getApplicationFromBody(req);
      await app?.kill();

      // Remove it from the list, and delete the directory.
      apps.remove(app.name);
      var appDir = await dartUpDir.appsDir.create(app.name);
      await appDir.delete();
      return app;
    });

    protectedRouter.post('/push', (req, res) async {
      await req.parseBody();
      var appDill = req.uploadedFiles.firstWhere(
          (f) => f.contentType.mimeType == 'application/dill',
          orElse: () => throw FormatException(
              'Missing application/dill file in payload.'));
      var pubspecYaml = req.bodyAsMap['pubspec'] as String;
      if (pubspecYaml == null) {
        throw FormatException('Missing "pubspec" field.');
      }

      // The user can specify a name for the app; otherwise,
      // default to the pubspec's name.
      var pubspec = Pubspec.parse(pubspecYaml);
      var appName = req.bodyAsMap['name'] as String ?? pubspec.name;

      // Kill existing application, if any.
      await apps.remove(appName)?.kill();

      // Download the dependencies.
      var appDir = await dartUpDir.appsDir.create(appName);
      await appDir.pubspecFile.writeAsString(pubspecYaml);
      var pub = await Process.run(pubPath, ['get', '--no-precompile'],
          workingDirectory: appDir.directory.path,
          stdoutEncoding: utf8,
          stderrEncoding: utf8);
      if (pub.exitCode != 0) {
        var b = StringBuffer();
        b..writeln(pub.stdout)..writeln(pub.stderr);
        logger.severe('$pubPath get failure', b.toString().trim());
        throw StateError('`$pubPath get` failed.');
      }

      // Write options
      var options = <String, dynamic>{};
      options[ApplicationDirectory.autoRestartOption] =
          req.bodyAsMap.containsKey(ApplicationDirectory.autoRestartOption);
      options[ApplicationDirectory.lambdaOption] =
          req.bodyAsMap.containsKey(ApplicationDirectory.lambdaOption);
      await appDir.optionsFile.writeAsString(json.encode(options));

      // Save the dill file, and spawn an isolate.
      await appDill.data.pipe(appDir.dillFile.openWrite());
      return apps[appName] = await appDir.spawn();
    });

    app.all('/:lambdaName', (req, res) async {
      var lambdaName = req.params['lambdaName'] as String;
      var app = apps[lambdaName];
      if (app == null) {
        throw AngelHttpException.notFound(
            message: 'No application named "$lambdaName" exists.');
      } else if (!app.isLambda) {
        throw AngelHttpException.forbidden(
            message: 'Application "$lambdaName" is not a lambda.');
      } else {
        // Spawn the app, if it's dead.
        // if (app.isDead) {
        await app.start();
        // }

        // Read headers
        var headers = <String, String>{};
        req.headers.forEach((k, v) {
          headers[k] = v.join(',');
        });

        // Read body into base64.
        var bb = await req.body
            .fold<BytesBuilder>(BytesBuilder(), (bb, blob) => bb..add(blob));

        // Send the request, and translate the response.
        var rq = Request(
          method: req.method,
          url: req.uri.toString(),
          headers: headers,
          bodyBase64: bb.isEmpty ? null : base64.encode(bb.takeBytes()),
        );
        var rs = await app.lambdaClient.send(rq);
        res
          ..statusCode = rs.statusCode
          ..headers.addAll(rs.headers);
        if (rs.bodyBase64 != null) {
          res.add(base64.decode(rs.bodyBase64));
        } else if (rs.text != null) {
          res.write(rs.text);
        }
      }
    });

    app.fallback((req, res) =>
        throw AngelHttpException.notFound(message: 'Invalid URL: ${req.uri}'));

    int port;
    if (isManaged) {
      port = 0;
    } else {
      port = int.parse(argResults['port'] as String);
    }

    await http.startServer(argResults['address'], port);

    if (isManaged) {
      print(http.server.port);
    } else {
      print('dart_up listening at ${http.uri}');
    }
  }
}
