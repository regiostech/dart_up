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
      ..addOption('address',
          abbr: 'a', defaultsTo: '127.0.0.1', help: 'The address to listen at.')
      ..addOption('port',
          abbr: 'p', defaultsTo: '2374', help: 'The port to listen to.');
  }

  run() async {
    hierarchicalLoggingEnabled = true;

    var logger = Logger('dart_up');
    logger.onRecord.listen(prettyLog);

    var app = Angel(logger: logger), http = AngelHttp(app);
    app.errorHandler = (e, req, res) => e;

    // Load the existing dart_up dir + config, etc.
    var dartUpDir = DartUpDirectory(Directory(p.join('.dart_tool', 'dart_up')));
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
      var app = apps[name];
      if (app == null) {
        throw AngelHttpException.notFound(
            message: 'No application named "$name" exists.');
      }
      return app;
    }

    app.get('/list', (req, res) => apps);

    app.post('/kill', (req, res) async {
      var app = await getApplicationFromBody(req);
      await app.kill();
      return app;
    });

    app.post('/start', (req, res) async {
      var app = await getApplicationFromBody(req);
      if (!app.isDead) {
        return app;
      } else {
        var appDir = await dartUpDir.appsDir.create(app.name);
        return apps[app.name] = await appDir.spawn();
      }
    });

    app.post('/remove', (req, res) async {
      // Kill the app.
      var app = await getApplicationFromBody(req);
      await app.kill();

      // Remove it from the list, and delete the directory.
      apps.remove(app.name);
      var appDir = await dartUpDir.appsDir.create(app.name);
      await appDir.delete();
      return app;
    });

    app.post('/push', (req, res) async {
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
      var pub = await Process.run('pub', ['get', '--no-precompile'],
          workingDirectory: appDir.directory.path);
      if (pub.exitCode != 0) {
        throw StateError('`pub get` failed.');
      }

      // Write options
      var options = <String, dynamic>{};
      options[ApplicationDirectory.autoRestartOption] =
          req.bodyAsMap.containsKey(ApplicationDirectory.autoRestartOption);
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
        if (app.isDead) {
          await app.start();
        }

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

    await http.startServer(
        argResults['address'], int.parse(argResults['port'] as String));
    print('dart_up listening at ${http.uri}');
  }
}
