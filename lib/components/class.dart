import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/object.dart';
import 'package:language/runtime/statements.dart';
import 'package:language/runtime/store.dart';

import 'util.dart';

class ClassStatement extends StaticStatement implements ClassChild {
  String className;
  bool abstract;
  Expression parentExpression;
  List<ClassChild> body;

  @override
  SideEffect execute() {
    if (!Store.current().has(className)) {
      // Register the type.
      var type =
          ClassType(className, body, abstract, parentExpression?.evaluate());

      Store.current().add(className, type.createConstant());
    }

    return SideEffect.nothing();
  }
}

class ClassDeclaration implements Statable {
  final _statement = ClassStatement();

  ClassDeclaration(TokenStream tokens) {
    const keywordMessage = 'Expected "class" or "abstract".';

    tokens.requireNext(keywordMessage, 1, TokenPattern.type(TokenType.Name));

    var keyword = tokens.current().toString();
    if (keyword != 'class' && keyword != 'abstract') {
      tokens.current().throwSyntax(keywordMessage, 1);
    }

    _statement.abstract = keyword == 'abstract';

    tokens.skip();

    tokens.requireNext('Expected class name after "class" keyword.', 2,
        TokenPattern.type(TokenType.Name));

    _statement.className = tokens.take().toString();

    const ofPattern = TokenPattern(string: 'of', type: TokenType.Name);
    var bracePattern = GroupPattern('{', '}');

    if (ofPattern.hasMatch(tokens.current())) {
      // Skip the 'of'.
      tokens.skip();

      var untilBraces = tokens.takeWhile(bracePattern.notMatch);
      _statement.parentExpression = Parse.expression(untilBraces);
    }

    tokens.requireNext(
        'Expected braces after class or superclass name.', 3, bracePattern);

    _statement.body = Parse.statements(tokens.take().allTokens()).cast();
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}
