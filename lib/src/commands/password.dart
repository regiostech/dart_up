import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dart_up/src/models.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;

class PasswordCommand extends Command {
  @override
  String get name => 'password';

  @override
  String get description =>
      'Sets (or overwrites) the password for a given username.';

  run() async {
    if (argResults.rest.isEmpty) {
      throw UsageException('A username must be provided.', usage);
    } else {
      var username = argResults.rest[0];
      var dartUpDir = DartUpDirectory(Directory.current);
      var password = await prompts.get('Password [hidden]', conceal: true);
      await dartUpDir.passwordFile.savePassword(username, password);
      print(green.wrap(
          'Successfully edited file ${dartUpDir.passwordFile.file.path}.'));
    }
  }
}
