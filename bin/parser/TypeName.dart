import '../Lexer.dart';
import '../runtime/Concepts.dart';
import '../runtime/Concrete.dart';
import '../runtime/Types.dart';
import 'Util.dart';

class TypeName {
  int line, column;
  String _name;
  TypeName _referencedType;

  TypeName(TokenStream tokens) {
    line = tokens.current().line;
    column = tokens.current().column;

    const atPattern = TokenPattern(string: '@', type: TokenType.Symbol);

    if (atPattern.hasMatch(tokens.current())) {
      // Reference type. Syntax is '@something' (e.g. '@int', '@string') or
      //  '@(something)' to allow modifiers. We don't currently support
      //  modifiers, though.
      // TODO: Modifiers.

      // Skip the '@'.
      tokens.skip();

      // Only the next token may be part of the type. This next token
      //  may be a group if parenthesised, in which case there may be
      //  multiple tokens. If not parenthesised, there may be one token
      //  only.
      // This may have to change to allow for qualified access to types.

      var containedTokens = tokens.current().allTokens();

      // Check for non-parenthesised groups (which are invalid).
      if (tokens.current() is GroupToken &&
          GroupPattern('(', ')').notMatch(tokens.current())) {
        throw InvalidSyntaxException(
            'Only a valid type name or parentheses may come after "@".',
            1,
            line,
            column);
      }

      _referencedType = TypeName(TokenStream(containedTokens, 0));

      // We only use one token, so skip once.
      tokens.skip();

      return;
    }

    tokens.requireNext('Type names must currently be single words.', 1,
        TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();
  }

  ValueType evaluate() {
    if (_referencedType != null) {
      return ReferenceType.forReferenceTo(_referencedType.evaluate());
    }

    if (_name == 'int') {
      return PrimitiveType(Primitive.Int);
    }

    if (_name == 'string') {
      return PrimitiveType(Primitive.String);
    }

    if (_name == 'any') {
      return AnyType();
    }

    // Only valid in function return type contexts.
    if (_name == 'proc') {
      return NoType();
    }

    throw InvalidSyntaxException(
        'Unable to evaluate type name $_name!', 1, line, column);
  }
}
