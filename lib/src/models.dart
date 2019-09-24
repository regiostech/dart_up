import 'dart:isolate';

class Application {
  Isolate isolate;
  bool isDead;

  Application();

  Application.fromJson(Map m) : isDead = m['is_dead'] == true;

  Map<String, dynamic> toJson() {
    return {
      'is_dead': isDead,
    };
  }
}
