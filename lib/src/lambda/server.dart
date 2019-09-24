import 'dart:async';
import 'package:dart_up/src/models.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';

class LambdaServer {
  final json_rpc_2.Server server;
  final FutureOr<Response> Function(Request) handleRequest;

  LambdaServer(this.server, this.handleRequest);

  LambdaServer.withoutJson(StreamChannel channel, this.handleRequest)
      : server = json_rpc_2.Server.withoutJson(channel);

  void close() => server.close();

  Future<void> listen() {
    server.registerMethod('request', (json_rpc_2.Parameters params) async {
      var rq = Request.fromJson(params.asMap.cast());
      return await handleRequest(rq);
    });
    return server.listen();
  }
}
