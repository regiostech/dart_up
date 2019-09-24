import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel_client/angel_client.dart';
import 'package:angel_client/io.dart';
import 'package:args/command_runner.dart';
import 'package:http/src/base_request.dart';
import 'package:http/src/streamed_response.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;

abstract class ClientCommand<T> extends Command<T> {
  ClientCommand() {
    argParser
      ..addFlag('basic-auth',
          abbr: 'B',
          negatable: false,
          help: 'Prompt for a username and password before taking action.')
      ..addOption('url',
          defaultsTo: 'http://127.0.0.1:2374',
          help: 'The URL of the running dart_up server.');
  }

  FutureOr<T> runWithClient(Angel app);

  Future<T> run() {
    Angel app = Rest(argResults['url'] as String);

    if (argResults['basic-auth'] as bool) {
      var username = prompts.get('Username');
      var password = prompts.get('Password', conceal: true);
      // var password = prompts.get('Password [hidden]', conceal: true);
      var authString = '$username:$password';
      var encoded = base64Url.encode(utf8.encode(authString));
      app = _InjectBasicAuth(app, encoded);
    }

    return Future.sync(() => runWithClient(app)).catchError((e) {
      stderr.writeln(red.wrap(e.toString()));
      exit(1);
    }).whenComplete(() {
      app.close();
      exit(0);
    });
  }
}

class _InjectBasicAuth extends Angel {
  final Angel inner;
  final String authString;

  _InjectBasicAuth(this.inner, this.authString) : super(inner.baseUrl);

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    request.headers['authorization'] ??= 'Basic $authString';
    return inner.send(request);
  }

  @override
  Future<void> close() {
    return inner.close();
  }

  @override
  Future<AngelAuthResult> authenticate(
      {String type,
      credentials,
      String authEndpoint = '/auth',
      String reviveEndpoint = '/auth/token'}) {
    return inner.authenticate(
        type: type, credentials: credentials, authEndpoint: authEndpoint);
  }

  @override
  Stream<String> authenticateViaPopup(String url,
      {String eventName = 'token'}) {
    return inner.authenticateViaPopup(url, eventName: eventName);
  }

  @override
  FutureOr<void> logout() => inner.logout();

  @override
  Stream<AngelAuthResult> get onAuthenticated => inner.onAuthenticated;

  @override
  Service<Id, Data> service<Id, Data>(String path,
      {Type type, AngelDeserializer<Data> deserializer}) {
    return inner.service(path, deserializer: deserializer);
  }
}
