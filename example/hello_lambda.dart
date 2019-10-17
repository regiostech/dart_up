import 'dart:isolate';
import 'package:up/lambda.dart';

main(_, SendPort sp) {
  return runLambda(
      sp,
      (req) => Response.text(
          'Hello, lambda world! Query: ${req.uri.queryParameters}'));
}
