import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;

class InstallCommand extends Command {
  @override
  String get name => 'install';

  @override
  String get description =>
      'Installs a systemd service that runs the dart_up daemon.';

  InstallCommand() {
    argParser
      ..addOption('working-directory',
          abbr: 'd',
          defaultsTo: '/etc/dart_up',
          help: 'The dart_up root directory.')
      ..addOption('out',
          abbr: 'o',
          defaultsTo: '/etc/systemd/system/dart_up.service',
          help: 'The path to the service file to write.')
      ..addOption('user',
          abbr: 'u',
          defaultsTo: 'web',
          help: 'The username to run the daemon as.');
  }

  run() async {
    var user = argResults['user'] as String;
    var workingDirectory = argResults['working-directory'] as String;
    var pubPath = p.join(getSdkPath(), 'bin', 'pub');
    var file = File(argResults['out'] as String);
    await file.writeAsString('''
[Unit]
Description=dart_up daemon
[Service]
User=$user
WorkingDirectory=$workingDirectory
ExecStart=$pubPath global run dart_up
Restart=always
[Install]
WantedBy=multi-user.target
'''
        .trim());
  }
}
