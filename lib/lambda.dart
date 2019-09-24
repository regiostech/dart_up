import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:dart_up/src/lambda/server.dart';
import 'package:dart_up/src/models.dart';
import 'package:stream_channel/isolate_channel.dart';

Future<void> runLambda(
    SendPort sp, FutureOr<Response> Function(Request) handleRequest) async {
  if (sp != null) {
    var channel = IsolateChannel.connectSend(sp);
    var server = LambdaServer.withoutJson(channel, handleRequest);
    await server.listen();
    await server.close();
  } else {
    // In development, just mount an HTTP server.
    var port = 8000;
    var http = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    http.listen((request) async {
      var response = request.response;
      var headers = <String, String>{};
      request.headers.forEach((k, _) => headers[k] = request.headers.value(k));
      var rq = Request(
          url: request.uri.toString(),
          method: request.method,
          headers: headers);
      var rs = await handleRequest(rq);
      response.statusCode = rs.statusCode;
      rs.headers?.forEach(response.headers.add);
      if (rs.text != null) {
        response.write(rs.text);
      } else if (rs.body != null) {
        response.add(rs.body);
      }
    });

    var url = Uri(scheme: 'http', host: http.address.address, port: http.port);
    print('Development server listening at $url');
  }
}
