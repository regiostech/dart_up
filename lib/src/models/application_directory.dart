import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'application.dart';

class ApplicationDirectory {
  final Directory directory;

  ApplicationDirectory(this.directory);

  static const String autoRestartOption = 'auto_restart',
      lambdaOption = 'lambda';

  String get name => p.basename(directory.path);

  File get packagesFile => File(p.join(directory.path, '.packages'));

  File get dillFile => File(p.join(directory.path, 'app.dill'));

  File get pubspecFile => File(p.join(directory.path, 'pubspec.yaml'));

  File get optionsFile => File(p.join(directory.path, 'dart_up_options.json'));

  Future<bool> get autoRestart async {
    var options = await readOptions();
    return options[autoRestartOption] == true;
  }

  Future<bool> get isLambda async {
    var options = await readOptions();
    return options[lambdaOption] == true;
  }

  Future<Map<String, dynamic>> readOptions() async {
    return await optionsFile
        .readAsString()
        .then(json.decode)
        .then((d) => d as Map<String, dynamic>);
  }

  Future<void> delete() async {
    await directory.delete(recursive: true);
  }

  Future<Application> spawn() async {
    var app = Application(name, await autoRestart, await isLambda,
        dillFile.absolute.uri, packagesFile.uri);
    await app.start();
    return app;
  }
}
