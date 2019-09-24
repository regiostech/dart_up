import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:body_parser/body_parser.dart';
import 'package:http_parser/http_parser.dart';
import 'package:json_annotation/json_annotation.dart';
part 'lambda.g.dart';

@JsonSerializable()
class Request {
  Uint8List _body;
  BodyParseResult _bodyParse;
  Uri _uri;

  @JsonKey(name: 'headers', includeIfNull: false)
  Map<String, String> headers;

  @JsonKey(name: 'path', includeIfNull: false)
  String url;

  Uri get uri => _uri ??= Uri.parse(url);

  @JsonKey(name: 'method', includeIfNull: false)
  String method;

  @JsonKey(name: 'body', includeIfNull: false)
  String bodyBase64;

  Map<String, dynamic> states = {};

  Request({this.headers = const {}, this.url, this.method, this.bodyBase64});

  List<int> get body {
    if (bodyBase64 == null) return [];
    return _body ??= base64.decode(bodyBase64);
  }

  Future<BodyParseResult> parseBody() async {
    if (_bodyParse != null) return _bodyParse;
    var contentType =
        MediaType.parse(headers['content-type'] ?? 'binary/octet-stream');
    return _bodyParse = await parseBodyFromStream(
        Stream.fromIterable([body]), contentType, uri);
  }

  Future<Map<String, dynamic>> parseBodyAsMap() async {
    var body = await parseBody();
    return body.body;
  }

  factory Request.fromJson(Map<String, dynamic> json) =>
      _$RequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestToJson(this);
}

@JsonSerializable()
class Response {
  Map<String, String> headers;

  int statusCode;

  String bodyBase64;

  String text;

  Response(
      {this.headers = const {},
      this.statusCode = 200,
      this.bodyBase64,
      this.text});

  factory Response.blob(List<int> data,
          {Map<String, String> headers = const {}, int statusCode = 200}) =>
      Response(
          bodyBase64: base64.encode(data),
          headers: {'content-type': 'text/plain'}..addAll(headers ?? {}),
          statusCode: statusCode);

  factory Response.text(String text,
          {Map<String, String> headers = const {}, int statusCode = 200}) =>
      Response(
          text: text,
          headers: {'content-type': 'text/plain'}..addAll(headers ?? {}),
          statusCode: statusCode);

  factory Response.json(value,
          {Map<String, String> headers = const {}, int statusCode = 200}) =>
      Response(
          text: json.encode(value),
          headers: {'content-type': 'application/json'}..addAll(headers ?? {}),
          statusCode: statusCode);

  factory Response.fromJson(Map<String, dynamic> json) =>
      _$ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ResponseToJson(this);
}
