import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/scope.dart';
import 'package:language/runtime/space.dart';
import 'package:language/runtime/statements.dart';

import 'util.dart';

class SpaceStatement extends StaticStatement implements ClassChild {
  List<StaticStatement> statements;
  String name;

  SpaceStatement(this.name, this.statements);

  @override
  SideEffect execute() {
    Scope.current().add(name, Space(statements).createConstant());

    return SideEffect.nothing();
  }
}

class SpaceDeclaration implements Statable {
  SpaceStatement? _statement;

  SpaceDeclaration(TokenStream tokens) {
    tokens.requireNext('Expected "space".', 1,
        TokenPattern(string: 'space', type: TokenType.Name));

    tokens.skip();

    tokens.requireNext('Expected space name after keyword.', 2,
        TokenPattern.type(TokenType.Name));

    var name = tokens.take().toString();

    tokens.requireNext(
        'Expected braces after space name.', 3, GroupPattern('{', '}'));

    var bodyTokens = tokens.take().allTokens();
    var statements = Parse.statements<StaticStatement>(bodyTokens);

    _statement = SpaceStatement(name, statements);
  }

  @override
  Statement? createStatement() {
    return _statement;
  }
}
