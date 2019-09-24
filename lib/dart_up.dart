import 'package:args/command_runner.dart';
import 'src/commands/kill.dart';
import 'src/commands/list.dart';
import 'src/commands/push.dart';
import 'src/commands/serve.dart';

final CommandRunner dartUpCommandRunner =
    CommandRunner('dart_up', 'Dart Web application container.')
      ..addCommand(KillCommand())
      ..addCommand(ListCommand())
      ..addCommand(PushCommand())
      ..addCommand(ServeCommand());
