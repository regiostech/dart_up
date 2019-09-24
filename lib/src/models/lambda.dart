import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
part 'lambda.g.dart';

@JsonSerializable()
class Request {
  Uri _uri;

  @JsonKey(name: 'headers', includeIfNull: false)
  Map<String, String> headers;

  @JsonKey(name: 'path', includeIfNull: false)
  String url;

  Uri get uri => _uri ??= Uri.parse(url);

  @JsonKey(name: 'method', includeIfNull: false)
  String method;

  @JsonKey(name: 'body', includeIfNull: false)
  Object body;

  Map<String, dynamic> states = {};

  Request({this.headers = const {}, this.url, this.method, this.body});

  Map<String, dynamic> get bodyAsMap => body as Map<String, dynamic>;

  factory Request.fromJson(Map<String, dynamic> json) =>
      _$RequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestToJson(this);
}

@JsonSerializable()
class Response {
  Map<String, String> headers;

  int statusCode;

  List<int> body;

  String text;

  Response(
      {this.headers = const {}, this.statusCode = 200, this.body, this.text});

  factory Response.text(String text,
          {Map<String, String> headers = const {}, int statusCode = 200}) =>
      Response(
          text: text,
          headers: {'content-type': 'application/json'}..addAll(headers ?? {}),
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
