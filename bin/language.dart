import 'dart:io';

import 'package:language/lexer.dart';
import 'package:language/parser/parser.dart';
import 'package:language/runtime/standard/io.dart';

void main(List<String> arguments) {
  registerIO();

  var toLex = File(arguments[0]).readAsStringSync();

  var lexer = Lexer(toLex);
  print(lexer.generatedTokens);

  var statements = Parse.statements(lexer.generatedTokens);
  for (var statement in statements) {
    statement.execute();
  }
}
