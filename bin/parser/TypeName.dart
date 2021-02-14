import '../Lexer.dart';
import '../runtime/Concepts.dart';
import '../runtime/Concrete.dart';
import 'Util.dart';

class TypeName {
  int line, column;
  String _name;

  TypeName(TokenStream tokens) {
    tokens.requireNext('Type names must currently be single words.', 1,
        TokenPattern.type(TokenType.Name));

    line = tokens.current().line;
    column = tokens.current().column;

    _name = tokens.take().toString();
  }

  ValueType evaluate() {
    if (_name == 'int') {
      return PrimitiveType(Primitive.Int);
    }

    if (_name == 'string') {
      return PrimitiveType(Primitive.String);
    }

    // TODO: Reference types.

    // Only valid in function return type contexts.
    if (_name == 'proc') {
      return NoType();
    }

    throw InvalidSyntaxException(
        'Unable to evaluate type name $_name!', 1, line, column);
  }
}
