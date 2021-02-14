import 'dart:io';

import 'Lexer.dart';
import 'parser/Parser.dart';
import 'runtime/standard/IO.dart';

void main(List<String> arguments) {
  registerIO();

  var toLex =
      File('/home/squ1dd13/Documents/Projects/Dart/Language/test_code/code.idk')
          .readAsStringSync();

  var lexer = Lexer(toLex);
  print(lexer.generatedTokens);

  var statements = Parse.statements(lexer.generatedTokens);
  for (var statement in statements) {
    statement.execute();
  }

  print('Done');

  // try {
  //   var stream = TokenStream(lexer.generatedTokens, 0);
  //   var declaration = VariableDeclaration(stream);
  //   declaration.createStatement().execute();
  //   print(declaration);
  //
  //   declaration = VariableDeclaration(stream);
  //   declaration.createStatement().execute();
  //
  //   var theVar = Store.current().getAs<Variable>('y');
  //
  //   var func = FunctionDeclaration(stream);
  //   print(func);
  // } on InvalidSyntaxException catch (exception) {
  //   print('Invalid syntax: $exception');
  // }
}
