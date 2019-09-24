import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'application_directory.dart';

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
