import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';

main() async {
  var app = Angel(), http = AngelHttp(app);
  app.fallback((req, res) => 'Hello from dart_up!');
  print('dart_up_example listening at ${http.uri}');
}
