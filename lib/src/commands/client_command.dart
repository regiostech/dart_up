import 'dart:async';
import 'package:angel_client/io.dart';
import 'package:args/command_runner.dart';

abstract class ClientCommand<T> extends Command<T> {
  ClientCommand() {
    argParser.addOption('url',
        defaultsTo: 'http://127.0.0.1:2374',
        help: 'The URL of the running dart_up server.');
  }

  FutureOr<T> runWithClient(Angel app);

  Future<T> run() async {
    var app = Rest(argResults['url'] as String);
    return await runWithClient(app);
    // return Future.sync(() => runWithClient(app))
    //     .whenComplete(() => app.close());
  }
}
