// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lambda.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Request _$RequestFromJson(Map<String, dynamic> json) {
  return Request(
    headers: (json['headers'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as String),
    ),
    url: json['path'] as String,
    method: json['method'] as String,
    bodyBase64: json['body'] as String,
  )..states = json['states'] as Map<String, dynamic>;
}

Map<String, dynamic> _$RequestToJson(Request instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('headers', instance.headers);
  writeNotNull('path', instance.url);
  writeNotNull('method', instance.method);
  writeNotNull('body', instance.bodyBase64);
  val['states'] = instance.states;
  return val;
}

Response _$ResponseFromJson(Map<String, dynamic> json) {
  return Response(
    headers: (json['headers'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as String),
    ),
    statusCode: json['statusCode'] as int,
    body: (json['body'] as List)?.map((e) => e as int)?.toList(),
    text: json['text'] as String,
  );
}

Map<String, dynamic> _$ResponseToJson(Response instance) => <String, dynamic>{
      'headers': instance.headers,
      'statusCode': instance.statusCode,
      'body': instance.body,
      'text': instance.text,
    };
