import '../Lexer.dart';
import 'Util.dart';

class FunctionDeclaration {
  Token _returnType;
  Token _name;
  GroupToken _parameters;
  GroupToken _body;

  FunctionDeclaration(TokenStream tokens) {
    // This may change in the future.
    tokens.requireNext('Functions must declare a return type.', 1,
        TokenPattern.type(TokenType.Name));

    _returnType = tokens.take();

    tokens.requireNext(
        'Function must have a name.', 2, TokenPattern.type(TokenType.Name));

    _name = tokens.take();

    // This /will/ change in the future.
    tokens.requireNext('Expected parameter list after function name.', 3,
        GroupPattern('(', ')'));

    _parameters = tokens.take() as GroupToken;

    tokens.requireNext('Expected function body after parameter list.', 4,
        GroupPattern('{', '}'));

    _body = tokens.take() as GroupToken;
  }
}
