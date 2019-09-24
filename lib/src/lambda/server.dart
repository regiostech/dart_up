import 'dart:async';
import 'package:dart_up/src/models.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';

class LambdaServer {
  final json_rpc_2.Server server;
  final FutureOr<Response> Function(Request) handleRequest;

  LambdaServer(this.server, this.handleRequest) {
    addHandlers();
  }

  LambdaServer.withoutJson(StreamChannel channel, this.handleRequest)
      : server = json_rpc_2.Server(channel.cast()) {
    addHandlers();
  }

  void close() => server.close();

  void addHandlers() {
    server.registerMethod('request', (json_rpc_2.Parameters params) async {
      var rq = Request.fromJson(params.asMap.cast());
      var rs = await handleRequest(rq);
      return rs.toJson();
    });
  }

  Future<void> listen() {
    return server.listen();
  }
}
