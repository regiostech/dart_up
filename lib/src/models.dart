import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

class DartUpDirectory {
  final Directory directory;
  DartUpAppsDirectory _appsDir;

  DartUpDirectory(this.directory);

  Future<void> initialize() async {
    await appsDir.directory.create(recursive: true);
  }

  DartUpAppsDirectory get appsDir => _appsDir ??=
      DartUpAppsDirectory(Directory(p.join(directory.path, 'apps')));
}

class DartUpAppsDirectory {
  final Directory directory;

  DartUpAppsDirectory(this.directory);

  Future<ApplicationDirectory> create(String name) async {
    var dir =
        await Directory(p.join(directory.path, name)).create(recursive: true);
    return ApplicationDirectory(dir);
  }

  Stream<ApplicationDirectory> findApps() async* {
    await for (var dir in directory.list()) {
      if (dir is Directory) {
        yield ApplicationDirectory(dir);
      }
    }
  }
}

class ApplicationDirectory {
  final Directory directory;

  ApplicationDirectory(this.directory);

  static final String autoRestartOption = 'auto_restart';

  String get name => p.basename(directory.path);

  File get packagesFile => File(p.join(directory.path, '.packages'));

  File get dillFile => File(p.join(directory.path, 'app.dill'));

  File get pubspecFile => File(p.join(directory.path, 'pubspec.yaml'));

  File get optionsFile => File(p.join(directory.path, 'dart_up_options.json'));

  Future<bool> get autoRestart async {
    var options = await readOptions();
    return options[autoRestartOption] == true;
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
    var isolate = await Isolate.spawnUri(dillFile.absolute.uri, [], null,
        packageConfig: packagesFile.uri);
    return Application(name, await autoRestart, dillFile.absolute.uri,
        packagesFile.uri, isolate);
  }
}

class Application {
  String name;
  Isolate isolate;
  bool autoRestart;
  bool isDead = false;
  Uri dillUri, packagesUri;
  ReceivePort onExit = ReceivePort(), onError = ReceivePort();
  Object error;

  Application(this.name, this.autoRestart, this.dillUri, this.packagesUri,
      this.isolate) {
    isolate.addOnExitListener(onExit.sendPort);
    isolate.addErrorListener(onError.sendPort);
    onExit.listen((_) async {
      isDead = true;
      if (autoRestart) {
        isolate = await Isolate.spawnUri(dillUri, [], null,
            packageConfig: packagesUri,
            onError: onError.sendPort,
            onExit: onExit.sendPort);
      }
    });
    onError.listen((e) => error = e);
  }

  Application.fromJson(Map m)
      : name = m['name']?.toString(),
        error = m['error'],
        isDead = m['is_dead'] == true;

  Future<void> kill() async {
    isolate.kill();
    isDead = true;
    onExit.close();
    onError.close();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'error': error?.toString(),
      'is_dead': isDead,
    };
  }

  @override
  String toString() {
    var buf = StringBuffer();
    buf.write(' • ');
    buf.write(styleBold.wrap(name));
    buf.write(' - ');
    if (isDead) {
      if (error != null) {
        buf.write(red.wrap('error'));
        buf.write(' - ');
        buf.write(red.wrap(error.toString()));
      } else {
        buf.write(darkGray.wrap('dead'));
      }
    } else {
      buf.write(green.wrap('alive'));
    }
    return buf.toString();
  }
}
