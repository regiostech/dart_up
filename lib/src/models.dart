import 'dart:async';
import 'dart:isolate';

class Application {
  Isolate isolate;
  bool isDead = false;

  Application();

  Application.fromJson(Map m) : isDead = m['is_dead'] == true;

  Future<void> kill() async {
    isolate.kill();
    isDead = true;
  }

  Map<String, dynamic> toJson() {
    return {
      'is_dead': isDead,
    };
  }
}
