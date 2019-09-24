import 'dart:async';
import 'dart:convert';
import 'package:angel_client/angel_client.dart';
import 'package:args/command_runner.dart';
import 'package:dart_up/src/models.dart';
import 'package:path/path.dart' as p;
import 'client_command.dart';

class KillCommand extends ClientCommand {
  @override
  String get name => 'kill';

  @override
  String get description => 'Kills a running application.';

  @override
  Future runWithClient(Angel app) async {
    if (argResults.rest.isEmpty) {
      throw UsageException('Missing application name.', usage);
    }

    var killUrl = app.baseUrl.replace(path: p.join(app.baseUrl.path, 'kill'));
    var response = await app.post(killUrl, body: {'name': argResults.rest[0]});

    var killed = Application.fromJson(json.decode(response.body) as Map);
    print(killed);
  }
}
