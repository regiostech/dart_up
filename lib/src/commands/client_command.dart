import 'dart:async';
import 'dart:io';
import 'package:angel_client/io.dart';
import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';

abstract class ClientCommand<T> extends Command<T> {
  ClientCommand() {
    argParser.addOption('url',
        defaultsTo: 'http://127.0.0.1:2374',
        help: 'The URL of the running dart_up server.');
  }

  FutureOr<T> runWithClient(Angel app);

  Future<T> run() {
    var app = Rest(argResults['url'] as String);
    // return await runWithClient(app);
    return Future.sync(() => runWithClient(app)).catchError((e) {
      stderr.writeln(red.wrap(e.toString()));
      exit(1);
    }).whenComplete(() {
      app.close();
      exit(0);
    });
  }
}
