import 'dart:async';
import 'dart:isolate';
import 'package:dart_up/src/lambda/client.dart';
import 'package:io/ansi.dart';
import 'package:stream_channel/isolate_channel.dart';

class Application {
  String name;
  Isolate isolate;
  bool autoRestart, isLambda;
  bool isDead = false;
  Uri dillUri, packagesUri;
  ReceivePort onExit = ReceivePort(), onError = ReceivePort(), lambdaPort;
  Object error;
  LambdaClient lambdaClient;

  Application(this.name, this.autoRestart, this.isLambda, this.dillUri,
      this.packagesUri) {
    onError.listen((e) => error = e);
    onExit.listen((_) async {
      isDead = true;
      if (autoRestart && !isLambda) {
        await start();
      }
    });
  }

  Future<void> start() async {
    SendPort message;
    if (isLambda) {
      lambdaClient?.close();
      lambdaPort?.close();
      lambdaPort = ReceivePort();
      message = lambdaPort.sendPort;
      lambdaClient =
          LambdaClient.withoutJson(IsolateChannel.connectReceive(lambdaPort));
    }

    isolate = await Isolate.spawnUri(dillUri, [], message,
        packageConfig: packagesUri,
        onError: onError.sendPort,
        onExit: onExit.sendPort);
  }

  Application.fromJson(Map m)
      : name = m['name']?.toString(),
        error = m['error'],
        isDead = m['is_dead'] == true;

  Future<void> kill() async {
    isolate.kill();
    isDead = true;
    onExit.close();
    onError.close();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'error': error?.toString(),
      'is_dead': isDead,
    };
  }

  @override
  String toString() {
    var buf = StringBuffer();
    buf.write(' • ');
    buf.write(styleBold.wrap(name));
    buf.write(' - ');
    if (isDead) {
      if (error != null) {
        buf.write(red.wrap('error'));
        buf.write(' - ');
        buf.write(red.wrap(error.toString()));
      } else {
        buf.write(darkGray.wrap('dead'));
      }
    } else {
      buf.write(green.wrap('alive'));
    }
    return buf.toString();
  }
}
