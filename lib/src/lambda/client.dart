import 'dart:async';
import 'package:up/src/models.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';

class LambdaClient {
  final json_rpc_2.Client client;

  LambdaClient(this.client) {
    client.listen();
  }

  LambdaClient.withoutJson(StreamChannel channel)
      : client = json_rpc_2.Client(channel.cast()) {
    client.listen();
  }

  void close() => client.close();

  Future<Response> send(Request req) async {
    var response = await client.sendRequest('request', req.toJson());
    return Response.fromJson((response as Map).cast());
  }

  // Future<void> listen() {
  //   server.registerMethod('request', (json_rpc_2.Parameters params) async {
  //     var rq = Request.fromJson(params.asMap.cast());
  //     return await handleRequest(rq);
  //   });
  //   return server.listen();
  // }
}
