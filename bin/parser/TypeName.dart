import '../Lexer.dart';
import '../runtime/Concepts.dart';
import '../runtime/Concrete.dart';
import 'Util.dart';

class TypeName {
  String _name;

  TypeName(TokenStream tokens) {
    tokens.requireNext('Type names must currently be single words.', 1,
        TokenPattern.type(TokenType.Name));
    _name = tokens.take().toString();
  }

  ValueType evaluate() {
    var primitive = _name == 'int' ? Primitive.Int : Primitive.String;
    return PrimitiveType(primitive);
  }
}
