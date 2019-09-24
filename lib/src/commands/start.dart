import 'dart:async';
import 'dart:convert';
import 'package:angel_client/angel_client.dart';
import 'package:args/command_runner.dart';
import 'package:dart_up/src/models.dart';
import 'package:path/path.dart' as p;
import 'client_command.dart';

class StartCommand extends ClientCommand {
  @override
  String get name => 'start';

  @override
  String get description => 'Restarts a dead/inactive process.';

  @override
  Future runWithClient(Angel app) async {
    if (argResults.rest.isEmpty) {
      throw UsageException('Missing application name.', usage);
    }

    var startUrl = app.baseUrl.replace(path: p.join(app.baseUrl.path, 'start'));
    var response = await app.post(startUrl, body: {'name': argResults.rest[0]});
    if (response.statusCode != 200) {
      throw AngelHttpException.fromJson(response.body);
    }

    var started = Application.fromJson(json.decode(response.body) as Map);
    print(started);
  }
}
