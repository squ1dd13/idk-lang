import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';

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

    _body = Parse.statements(tokens.take().allTokens());

    // #error anonymous type constructor (how?) and other stuff
  }

  @override
  Statement createStatement() {
    // TODO: implement createStatement
    throw UnimplementedError();
  }
}
