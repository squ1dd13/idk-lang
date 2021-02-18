import 'dart:io';

import 'package:language/lexer.dart';
import 'package:language/parser/operation.dart';
import 'package:language/parser/parser.dart';
import 'package:language/runtime/standard/language_core.dart';

void main(List<String> arguments) {
  registerCore();

  var tokens = Lexer('(13 + 11) * myFunc(10, 2, 3, (9 * 2)) / someArray[2]')
      .generatedTokens;
  var postfix = infixToPostfix(tokens);

  var toLex = File(arguments[0]).readAsStringSync();

  var lexer = Lexer(toLex);
  print(lexer.generatedTokens);

  var statements = Parse.statements(lexer.generatedTokens);
  for (var statement in statements) {
    statement.execute();
  }
}
