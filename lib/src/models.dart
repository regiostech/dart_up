import 'dart:async';
import 'dart:isolate';

class Application {
  Isolate isolate;
  bool isDead = false;
  ReceivePort onExit = ReceivePort(), onError = ReceivePort();
  Object error;

  Application(this.isolate) {
    isolate.addOnExitListener(onExit.sendPort);
    isolate.addErrorListener(onError.sendPort);
    onExit.listen((_) => isDead = true);
    onError.listen((e) => error = e);
  }

  Application.fromJson(Map m)
      : error = m['error'],
        isDead = m['is_dead'] == true;

  Future<void> kill() async {
    isolate.kill();
    isDead = true;
    onExit.close();
    onError.close();
  }

  Map<String, dynamic> toJson() {
    return {
      'error': error?.toString(),
      'is_dead': isDead,
    };
  }
}
