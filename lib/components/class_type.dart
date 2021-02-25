import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/statements.dart';

import 'constructor.dart';
import 'util.dart';

/// A `type` block. Used to implement templates and other complex type
/// behaviour within a class definition.
class CustomClassType implements Statable {
  List<Statement> _body;

  CustomClassType(TokenStream tokens) {
    tokens.requireNext('Expected "type" at start of type block.', 1,
        TokenPattern(string: 'type', type: TokenType.Name));

    tokens.skip();

    tokens.requireNext(
        'Expected braces after "type" keyword.', 2, GroupPattern('{', '}'));

    var anonymousConstructor = (TokenStream stream) =>
        ConstructorDeclaration(stream, anonymous: true).createStatement();

    // Parse the body, but with a pass for an anonymous constructor as well.
    var passes = [anonymousConstructor] + Parse.statementPasses;

    _body = Parse.statements(tokens.take().allTokens(), passes: passes);
  }

  @override
  Statement createStatement() {
    throw UnimplementedError();
    // return SideEffectStatement(() {
    //   for (var statement in _body) {
    //     statement.execute();
    //   }
    //
    //   return SideEffect.nothing();
    // }, static: true);
  }
}
