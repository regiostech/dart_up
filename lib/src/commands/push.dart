import 'dart:async';
import 'dart:io';
import 'package:angel_client/angel_client.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'client_command.dart';

class PushCommand extends ClientCommand {
  @override
  String get name => 'push';

  @override
  String get description =>
      'Builds an app snapshot, and pushes it to a dart_up server.';

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
        var uri = app.baseUrl.replace(path: p.join(app.baseUrl.path, 'add'));
        var rq = http.MultipartRequest('POST', uri);
        rq.files.add(await http.MultipartFile.fromPath('app_dill', dillFile));
        rq.files
            .add(await http.MultipartFile.fromPath('pubspec', 'pubspec.yaml'));
        var rs = await app.send(rq).then(http.Response.fromStream);
        if (rs.statusCode != 200) {
          throw AngelHttpException.fromJson(rs.body);
        } else {
          // TODO: Print application from response.
          print(green.wrap('Successfully pushed application.'));
        }
      }
    }
  }
}
