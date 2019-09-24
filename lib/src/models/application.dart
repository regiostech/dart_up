import 'dart:async';
import 'dart:isolate';
import 'package:dart_up/src/lambda/client.dart';
import 'package:io/ansi.dart';
import 'package:stream_channel/isolate_channel.dart';

class Application {
  String name;
  Isolate isolate;
  bool autoRestart, isLambda;
  bool isDead = true;
  Uri dillUri, packagesUri;
  ReceivePort onExit = ReceivePort(), onError = ReceivePort(), lambdaPort;
  Object error;
  LambdaClient lambdaClient;
  Duration lambdaKillDuration = Duration(seconds: 10);
  Timer lambdaKillTimer;

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
    if (!isDead) return;
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
    isDead = false;

    if (isLambda) {
      lambdaKillTimer?.cancel();
      lambdaKillTimer = Timer(lambdaKillDuration, kill);
    }
  }

  Application.fromJson(Map m)
      : name = m['name']?.toString(),
        error = m['error'],
        isDead = m['is_dead'] == true;

  Future<void> kill() async {
    lambdaKillTimer?.cancel();
    lambdaClient?.close();
    isolate?.kill();
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
