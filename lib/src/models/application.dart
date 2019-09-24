import 'dart:async';
import 'dart:isolate';
import 'package:io/ansi.dart';

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
