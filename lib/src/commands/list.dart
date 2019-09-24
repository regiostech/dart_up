import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel_client/angel_client.dart';
import 'package:dart_up/src/models.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'client_command.dart';

class ListCommand extends ClientCommand {
  @override
  String get name => 'list';

  @override
  String get description =>
      'Lists the status of all active applications within the dart_up instance.';

  @override
  Future runWithClient(Angel app) async {
    var listUrl = app.baseUrl.replace(path: p.join(app.baseUrl.path, 'list'));
    var response = await app.get(listUrl);
    var data = (json.decode(response.body) as Map)
        .cast<String, Map<String, dynamic>>();
    if (data.isEmpty) {
      print('No active applications.');
    }
    data.forEach((name, appM) {
      var app = Application.fromJson(appM);
      stdout.write(' • $name (');
      if (app.isDead) {
        // TODO: Print errors
        if (app.error != null) {
          stdout.write(red.wrap('error'));
          stdout.write(') • ${app.error}');
        } else {
          stdout.write(darkGray.wrap('dead'));
          stdout.write(')');
        }
      } else {
        stdout.write(green.wrap('alive'));
        stdout.write(')');
      }
      stdout.writeln();
    });
  }
}
