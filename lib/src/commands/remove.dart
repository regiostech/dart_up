import 'dart:async';
import 'dart:convert';
import 'package:angel_client/angel_client.dart';
import 'package:args/command_runner.dart';
import 'package:dart_up/src/models.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'client_command.dart';

class RemoveCommand extends ClientCommand {
  @override
  String get name => 'remove';

  @override
  String get description => 'Kills, and removes an application from the list.';

  @override
  Future runWithClient(Angel app) async {
    if (argResults.rest.isEmpty) {
      throw UsageException('Missing application name.', usage);
    }

    var removeUrl =
        app.baseUrl.replace(path: p.join(app.baseUrl.path, 'remove'));
    var response =
        await app.post(removeUrl, body: {'name': argResults.rest[0]});
    if (response.statusCode != 200) {
      throw AngelHttpException.fromJson(response.body);
    }

    var removed = Application.fromJson(json.decode(response.body) as Map);
    print(green.wrap('Successfully removed app:'));
    print(removed);
  }
}
