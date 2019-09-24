import 'dart:async';
import 'package:dart_up/src/models.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';

abstract class LambdaServer {
  final json_rpc_2.Server server;

  LambdaServer(this.server);

  LambdaServer.withoutJson(StreamChannel channel)
      : server = json_rpc_2.Server.withoutJson(channel);

  FutureOr<Response> handleRequest(Request req);

  void close() => server.close();

  Future<void> listen() {
    server.registerMethod('request', (json_rpc_2.Parameters params) async {
      var rq = Request.fromJson(params.asMap.cast());
      return await handleRequest(rq);
    });
    return server.listen();
  }
}
