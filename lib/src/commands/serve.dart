import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:pretty_logging/pretty_logging.dart';

class ServeCommand extends Command {
  @override
  String get name => 'serve';

  @override
  String get description =>
      'Launch an HTTP server that manages other Dart applications.';

  ServeCommand() {
    argParser
      ..addOption('address',
          abbr: 'a', defaultsTo: '127.0.0.1', help: 'The address to listen at.')
      ..addOption('port',
          abbr: 'p', defaultsTo: '2374', help: 'The port to listen to.');
  }

  run() async {
    hierarchicalLoggingEnabled = true;
    var logger = Logger('dart_up');
    logger.onRecord.listen(prettyLog);

    var app = Angel(logger: logger), http = AngelHttp(app);
    app.errorHandler = (e, req, res) => e;

    await http.startServer(
        argResults['address'], int.parse(argResults['port'] as String));
    print('dart_up listening at ${http.uri}');
  }
}
