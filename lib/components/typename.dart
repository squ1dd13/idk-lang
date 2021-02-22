import 'package:language/runtime/expression.dart';

import '../lexer.dart';
import '../runtime/type.dart';
import 'operations/expression.dart';
import 'util.dart';

class TypeName {
  Expression _typeExpression;

  TypeName(TokenStream tokens) {
    const letPattern = TokenPattern(string: 'let', type: TokenType.Name);

    if (letPattern.hasMatch(tokens.current())) {
      // 'let' means the value gives the type.
      _typeExpression = null;
      tokens.skip();
      return;
    }

    // Once we find '[]' in the type, we only read more '[]' tokens. If we find
    //  something else, it isn't part of the type.
    var foundBrackets = false;
    var foundNonModifierWord = false;
    var bracketPattern = GroupPattern('[', ']');

    bool isModifier(Token token) {
      return false;
    }

    // tokens.saveIndex();
    var typeTokens = tokens.takeWhile((token) {
      if (bracketPattern.hasMatch(token)) {
        return foundBrackets = true;
      }

      if (foundBrackets) {
        // We don't want this token because it is a non-bracket token
        //  that comes after the point where we only read bracket tokens.
        return false;
      }

      if (token.type == TokenType.Name) {
        if (foundNonModifierWord) {
          // Only one non-modifier word is allowed.
          return false;
        }

        if (!isModifier(token)) {
          foundNonModifierWord = true;
        }
      }

      return true;
    });

    _typeExpression = OperatorExpression(TokenStream(typeTokens, 0));
  }

  ValueType evaluate() {
    return _typeExpression?.evaluate()?.value;
  }
}
