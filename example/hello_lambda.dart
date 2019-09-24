import 'dart:isolate';
import 'package:dart_up/lambda.dart';

main(_, SendPort sp) {
  return runLambda(sp, (req) => Response.text('Hello, lambda world!'));
}
