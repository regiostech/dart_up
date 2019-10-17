import 'dart:async';
import 'dart:convert';
import 'package:angel_client/angel_client.dart';
import 'package:up/src/models.dart';
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
    if (response.statusCode != 200) {
      throw AngelHttpException.fromJson(response.body);
    }
    var data = (json.decode(response.body) as Map)
        .cast<String, Map<String, dynamic>>();
    if (data.isEmpty) {
      print('No active applications.');
    }
    data.forEach((name, appM) {
      print(Application.fromJson(appM));
    });
  }
}
