import 'dart:io';

import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/standard/language_core.dart';

void main(List<String> arguments) {
  registerCore();

  var toLex = File(arguments[0]).readAsStringSync();

  var lexer = Lexer(toLex);
  print(lexer.generatedTokens);

  var statements = Parse.statements(lexer.generatedTokens);
  for (var statement in statements) {
    statement.execute();
  }
}
