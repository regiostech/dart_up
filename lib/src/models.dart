import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:io/ansi.dart';

class Application {
  String name;
  Isolate isolate;
  bool isDead = false;
  ReceivePort onExit = ReceivePort(), onError = ReceivePort();
  Object error;

  Application(this.name, this.isolate) {
    isolate.addOnExitListener(onExit.sendPort);
    isolate.addErrorListener(onError.sendPort);
    onExit.listen((_) => isDead = true);
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
    buf.write(' • $name (');
    if (isDead) {
      if (error != null) {
        buf.write(red.wrap('error'));
        buf.write(') • $error');
      } else {
        buf.write(darkGray.wrap('dead'));
        buf.write(')');
      }
    } else {
      buf.write(green.wrap('alive'));
      buf.write(')');
    }
    buf.writeln();
    return buf.toString();
  }
}
