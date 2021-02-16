import '../Lexer.dart';
import '../runtime/Concepts.dart';
import '../runtime/Concrete.dart';
import '../runtime/Exceptions.dart';
import '../runtime/Expression.dart';
import '../runtime/Store.dart';
import '../runtime/Types.dart';
import 'Parser.dart';
import 'TypeName.dart';
import 'Util.dart';

/// The initial direction of a reference, such as:
/// ```
/// @int myReference -> someVariable;
/// ```
class Direction implements Statable {
  TypeName _typeName;
  String _name;
  Expression _targetExpression;

  /// Parses the part of the direction which is common between directions
  /// and redirections.
  Direction._common(TokenStream tokens) {
    tokens.requireNext(
        'Expected name in direction.', 1, TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();

    tokens.requireNext('Expected "->" in direction.', 2,
        TokenPattern(string: '->', type: TokenType.Symbol));

    tokens.skip();

    var expressionTokens = tokens.takeWhile(TokenPattern.semicolon.notMatch);
    if (expressionTokens.isEmpty) {
      throw tokens.createException(
          'Direction target expression may not be empty.', 3);
    }

    _targetExpression = Parse.expression(expressionTokens);

    tokens.consumeSemicolon(4);
  }

  factory Direction.redirection(TokenStream tokens) {
    return Direction._common(tokens);
  }

  factory Direction(TokenStream tokens) {
    // For full directions (basically reference declarations).
    var typeName = TypeName(tokens);

    var common = Direction._common(tokens);
    common._typeName = typeName;

    return common;
  }

  @override
  Statement createStatement() {
    return Statement(InlineExpression(() {
      // Evaluate the expression and then create a variable with the type.
      var evaluated = _targetExpression.evaluate();

      var reference = Reference(evaluated);

      if (_typeName == null) {
        Store.current()
            .getAs<Reference>(_name)
            .set(evaluated.get() as TypedValue);
      } else {
        Store.current().add(_name, reference);
      }

      var storedReference = Store.current().getAs<Reference>(_name);
      var requiredType = _typeName?.evaluate() ??
          ReferenceType.forReferenceTo((evaluated as TypedValue).type);

      if (storedReference.type.conversionTo(requiredType) !=
          TypeConversion.NoConversion) {
        var targetType = (storedReference.type as ReferenceType).referencedType;
        throw RuntimeError('Cannot direct "$requiredType" to "$targetType".');
      }

      storedReference.type = requiredType;

      return null;
    }));
  }
}

/// Inline direction of references.
/// ```
/// someFunction(-> target);
/// ```
class InlineDirection implements Expressible {
  Expression _targetExpression;

  InlineDirection(TokenStream tokens) {
    tokens.requireNext('Token direction must begin with "->".', 1,
        TokenPattern(string: '->', type: TokenType.Symbol));

    tokens.skip();

    // The next must be a single token, so multiple tokens must be
    //  parenthesised.
    var expressionTokens = tokens.take().allTokens();
    _targetExpression = Parse.expression(expressionTokens);
  }

  @override
  Expression createExpression() {
    return InlineExpression(() => Reference(_targetExpression.evaluate()));
  }
}
