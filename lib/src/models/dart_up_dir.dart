import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:path/path.dart' as p;
import 'application_directory.dart';

class DartUpDirectory {
  final Directory directory;
  final dbCrypt = DBCrypt();
  DartUpAppsDirectory _appsDir;
  DartUpPasswordFile _passwordFile;

  DartUpDirectory(this.directory);

  DartUpAppsDirectory get appsDir => _appsDir ??=
      DartUpAppsDirectory(Directory(p.join(directory.path, 'apps')));

  DartUpPasswordFile get passwordFile => _passwordFile ??=
      DartUpPasswordFile(dbCrypt, File(p.join(directory.path, 'passwords')));

  Future<void> initialize() async {
    await appsDir.directory.create(recursive: true);
  }
}

class DartUpPasswordFile {
  final DBCrypt dbCrypt;
  final File file;

  DartUpPasswordFile(this.dbCrypt, this.file);

  Future<bool> verify(String username, String password) async {
    var pws = await read();
    var pw = pws[username];
    if (pw == null) return false;
    return dbCrypt.hashpw(password, pw.salt) == pw.hashedPassword;
  }

  Future<Map<String, DartUpPassword>> read() async {
    var out = <String, DartUpPassword>{};
    if (await file.exists()) {
      var lines =
          file.openRead().transform(utf8.decoder).transform(LineSplitter());
      await for (var line in lines) {
        var parts =
            line.split(':').map((s) => s.trim()).where((s) => s.isNotEmpty);
        if (parts.length == 3) {
          var pw = DartUpPassword.fromParts(parts.toList());
          out[pw.username] = pw;
        }
      }
    }
    return out;
  }
}

class DartUpPassword {
  String username, salt, hashedPassword;

  DartUpPassword(this.username, this.salt, this.hashedPassword);

  DartUpPassword.fromParts(List<String> parts)
      : username = parts[0],
        salt = parts[1],
        hashedPassword = parts[2];
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
