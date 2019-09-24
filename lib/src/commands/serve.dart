import 'dart:io';
import 'dart:isolate';
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

    var apps = <String, Application>{};

    // Spawn every app we have saved.
    var dartUpDir = await Directory(p.join('.dart_tool', 'dart_up'))
        .create(recursive: true);
    var dartUpAppsDir =
        await Directory(p.join(dartUpDir.path, 'apps')).create(recursive: true);

    await for (var dir in dartUpAppsDir.list()) {
      if (dir is Directory) {
        var name = p.basename(dir.path);
        // Find the app.dill and .packages.
        var packagesFile = File(p.join(dir.path, '.packages'));
        // Save the dill file, and spawn an isolate.
        var dillFile = File(p.join(dir.path, 'app.dill'));
        var isolate = await Isolate.spawnUri(dillFile.uri, [], null,
            packageConfig: packagesFile.uri);
        var appModel = Application(isolate);
        apps[name] = appModel;
        return appModel;
      }
    }

    app.get('/list', (req, res) => apps);

    app.post('/add', (req, res) async {
      await req.parseBody();
      var appDill = req.uploadedFiles.firstWhere(
          (f) => f.contentType.mimeType == 'application/dill',
          orElse: () => throw FormatException(
              'Missing application/dill file in payload.'));
      var pubspecYaml = req.bodyAsMap['pubspec'] as String;
      if (pubspecYaml == null) {
        throw FormatException('Missing "pubspec" field.');
      }
      var pubspec = Pubspec.parse(pubspecYaml);
      // Kill existing application, if any.
      await apps.remove(pubspec.name)?.kill();
      // Download the dependencies into a temp dir.
      // var appDir = await Directory.systemTemp.createTemp();
      var appDir =
          await Directory(p.join('.dart_tool', 'dart_up', 'apps', pubspec.name))
              .create(recursive: true);
      // req.shutdownHooks.add(() => tempDir.delete(recursive: true));
      var pubspecFile = File(p.join(appDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString(pubspecYaml);
      var pub = await Process.run('pub', ['get', '--no-precompile']);
      // TODO: Handle error
      var packagesFile = File(p.join(appDir.path, '.packages'));
      // Save the dill file, and spawn an isolate.
      var dillFile = File(p.join(appDir.path, 'app.dill'));
      await appDill.data.pipe(dillFile.openWrite());
      // Use the temp dir's .packages file
      var isolate = await Isolate.spawnUri(dillFile.uri, [], null,
          packageConfig: packagesFile.uri);
      var appModel = Application(isolate);
      apps[pubspec.name] = appModel;
      return appModel;
    });

    app.fallback((req, res) => throw AngelHttpException.notFound());

    await http.startServer(
        argResults['address'], int.parse(argResults['port'] as String));
    print('dart_up listening at ${http.uri}');
  }
}
