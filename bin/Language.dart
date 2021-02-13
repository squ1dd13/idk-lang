import 'dart:io';

import 'Lexer.dart';
import 'parser/Function.dart';
import 'parser/Util.dart';
import 'parser/VariableDeclaration.dart';

void main(List<String> arguments) {
  var toLex =
      File('/home/squ1dd13/Documents/Projects/Dart/Language/test_code/code.idk')
          .readAsStringSync();

  var lexer = Lexer(toLex);
  print(lexer.generatedTokens);

  try {
    var stream = TokenStream(lexer.generatedTokens, 0);
    var declaration = VariableDeclaration(stream);
    print(declaration);

    var func = FunctionDeclaration(stream);
    print(func);
  } on InvalidSyntaxException catch (exception) {
    print('Invalid syntax: $exception');
  }
}
