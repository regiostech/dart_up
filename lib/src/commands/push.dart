import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel_client/angel_client.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:dart_up/src/models.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'client_command.dart';

class PushCommand extends ClientCommand {
  @override
  String get name => 'push';

  @override
  String get description =>
      'Builds an app snapshot, and pushes it to a dart_up server.';

  PushCommand() {
    argParser
      ..addFlag('auto-restart',
          defaultsTo: true, help: 'Automatically restart the app on exit.')
      ..addOption('name',
          abbr: 'n',
          help:
              'An explicit name for the application; otherwise the pubspec.yaml name is used.');
  }

  @override
  Future runWithClient(Angel app) async {
    if (argResults.rest.isEmpty) {
      throw UsageException('A path to a .dart file must be provided.', usage);
    } else {
      var dillFile = p.join(
          '.dart_tool', 'dart_up', p.setExtension(argResults.rest[0], '.dill'));
      await Directory(p.dirname(dillFile)).create(recursive: true);
      var logger = Logger.standard(); // TODO: Verbose?
      var progress = logger.progress(lightGray.wrap('Building $dillFile...'));
      var dart = await Process.start(Platform.resolvedExecutable,
          ['--snapshot=$dillFile', argResults.rest[0]],
          mode: ProcessStartMode.inheritStdio);
      var exitCode = await dart.exitCode;
      await progress.finish(showTiming: true);
      if (exitCode != 0) {
        stderr.writeln(red.wrap('Building a snapshot failed.'));
      } else {
        var pushUrl =
            app.baseUrl.replace(path: p.join(app.baseUrl.path, 'push'));
        var rq = http.MultipartRequest('POST', pushUrl);
        if (argResults.wasParsed('name')) {
          rq.fields['name'] = argResults['name'] as String;
        }
        if (argResults['auto-restart'] as bool) {
          rq.fields[ApplicationDirectory.autoRestartOption] = '1';
        }
        rq.fields['pubspec'] = await File('pubspec.yaml').readAsString();
        rq.files.add(await http.MultipartFile.fromPath(
          'app_dill',
          dillFile,
          contentType: MediaType('application', 'dill'),
        ));
        var rs = await app.send(rq).then(http.Response.fromStream);
        if (rs.statusCode != 200) {
          throw AngelHttpException.fromJson(rs.body);
        } else {
          var app = Application.fromJson(json.decode(rs.body) as Map);
          print(app);
        }
      }
    }
  }
}
