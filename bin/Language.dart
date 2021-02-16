import 'dart:io';

import 'Lexer.dart';
import 'parser/Parser.dart';
import 'runtime/standard/IO.dart';

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
