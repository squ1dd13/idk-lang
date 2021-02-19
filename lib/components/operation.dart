import 'dart:math';

import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/abstract.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/type.dart';

class OperatorExpression implements Expression {
  List<Token> _tokens;

  OperatorExpression(TokenStream tokens) {
    // Infix expressions can't have two operands next to each other,
    //  so the expression ends when we find a semicolon or two tokens
    //  that would be operands.

    var lastWasOperand = false;
    var found = <Token>[];

    while (tokens.hasCurrent() &&
        TokenPattern.semicolon.notMatch(tokens.current())) {
      var notOperator = tokens.current().isNotOperator;

      if (notOperator && lastWasOperand) {
        break;
      }

      found.add(tokens.take());
      lastWasOperand = notOperator;
    }

    _tokens = ShuntingYard.toPostfix(found);
  }

  @override
  Evaluable evaluate() {
    return ShuntingYard.evaluate(_tokens);
  }
}

class TokenOperator implements Function {
  double precedence;
  bool rightAssociative;
  bool isUnary;
  String warning;
  final Value Function(Iterable<Value> operands) _implementation;

  TokenOperator(this.precedence, this._implementation,
      {this.rightAssociative = false,
      this.isUnary = false,
      this.warning = ''}) {
    if (isUnary) {
      // We don't have postfix yet, so this is fine.
      rightAssociative = true;
    }
  }

  void issueWarningIfAny(int line, int column) {
    if (warning?.isEmpty ?? true) {
      return;
    }

    print('Warning: ($line, $column) $warning');
  }

  Value call(Iterable<Value> operands) {
    return _implementation(operands);
  }
}

/// Implements the operators. For many, we can just pass through to Dart's
/// operators, although there are some where we have to add extra behaviour.
class _Operations {
  static dynamic _getRaw<T>(Value v) {
    var value = v.get();

    if (T == bool) {
      return (_getRaw<int>(value) != 0 ? true : false);
    }

    if (value.type == PrimitiveType.integer) {
      return (value as IntegerValue).rawValue;
    }

    // TODO: We need a mustConvertTo here.
    return ((value as PrimitiveValue).rawValue as T);
  }

  static final _wrapConversions = <Type, PrimitiveValue Function(dynamic)>{
    int: (v) => IntegerValue.raw(v),
    String: (v) => StringValue(v),
    bool: (v) => IntegerValue.raw(v ? 1 : 0),
    double: (v) => IntegerValue.raw((v as double).truncate()),
  };

  /// Take a value of unknown type and convert it to an appropriately typed
  /// [PrimitiveValue].
  static PrimitiveValue _wrapPrimitive(dynamic value) {
    var conversion = _wrapConversions[value.runtimeType];

    if (conversion == null) {
      throw RuntimeError('Unable to wrap value of type "${value.runtimeType}" '
          'in any primitive.');
    }

    return conversion(value);
  }

  static Value exponent(Iterable<Value> operands) {
    return _wrapPrimitive(pow(_getRaw(operands.first), _getRaw(operands.last)));
  }

  static Value preIncrement(Iterable<Value> operands) {
    var oldValue = _wrapPrimitive(_getRaw(operands.first));
    (operands.first as Variable)
        .set(_wrapPrimitive(_getRaw(operands.first) + 1));

    return oldValue;
  }

  static Value squareBrackets(Iterable<Value> operands) {
    // "Type[]" is an array of values of type 'Type'.
    if (operands.first is ValueType) {
      return ArrayType(operands.first as ValueType);
    }

    // "something[n]" is an access to the nth item in the 'something'.
    return operands.first.at(operands.last);
  }

  static Value getAtIndex(Iterable<Value> operands) {
    return operands.first.at(operands.last);
  }

  static Value createArrayType(Iterable<Value> operands) {
    return ArrayType(operands.first as ValueType);
  }

  static Value not(Iterable<Value> operands) {
    return _wrapPrimitive(_getRaw<int>(operands.first) != 0 ? 0 : 1);
  }

  static Value bitnot(Iterable<Value> operands) {
    return _wrapPrimitive(~_getRaw<int>(operands.first));
  }

  static Value redirect(Iterable<Value> operands) {
    var target = operands.last;
    var reference = operands.first as Reference;

    var targetType = ReferenceType.forReferenceTo(target.type);

    if (reference.type.conversionTo(targetType) !=
        TypeConversion.NoConversion) {
      var targetType = (reference.type as ReferenceType).referencedType;
      throw RuntimeError('Cannot direct "$targetType" to "$targetType".');
    }

    reference.set(target.get());

    return null;
  }

  static Value unaryMinus(Iterable<Value> operands) {
    return _wrapPrimitive(-_getRaw(operands.first));
  }

  static Value referenceTo(Iterable<Value> operands) {
    return ReferenceType.forReferenceTo(operands.first);
  }

  static Value multiply(Iterable<Value> operands) {
    return _wrapPrimitive(_getRaw(operands.first) * _getRaw(operands.last));
  }

  static Value divide(Iterable<Value> operands) {
    return _wrapPrimitive(_getRaw(operands.first) / _getRaw(operands.last));
  }

  static Value modulus(Iterable<Value> operands) {
    return _wrapPrimitive(_getRaw(operands.first) % _getRaw(operands.last));
  }

  static Value add(Iterable<Value> operands) {
    return _wrapPrimitive(_getRaw(operands.first) + _getRaw(operands.last));
  }

  static Value subtract(Iterable<Value> operands) {
    return _wrapPrimitive(_getRaw(operands.first) - _getRaw(operands.last));
  }

  static Value lessThan(Iterable<Value> operands) {
    return _wrapPrimitive(operands.first.lessThan(operands.last));
  }

  static Value lessThanOrEqual(Iterable<Value> operands) {
    return _wrapPrimitive(operands.first.lessThanOrEqualTo(operands.last));
  }

  static Value greaterThan(Iterable<Value> operands) {
    return _wrapPrimitive(operands.first.greaterThan(operands.last));
  }

  static Value greaterThanEqual(Iterable<Value> operands) {
    return _wrapPrimitive(operands.first.greaterThanOrEqualTo(operands.last));
  }

  static Value cast(Iterable<Value> operands) {
    return operands.first.mustConvertTo(operands.last);
  }

  static Value equal(Iterable<Value> operands) {
    return _wrapPrimitive(operands.first.equals(operands.last));
  }

  static Value notEqual(Iterable<Value> operands) {
    return _wrapPrimitive(operands.first.notEquals(operands.last));
  }

  static Value bitand(Iterable<Value> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first) & _getRaw<int>(operands.last));
  }

  static Value xor(Iterable<Value> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first) ^ _getRaw<int>(operands.last));
  }

  static Value bitor(Iterable<Value> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first) | _getRaw<int>(operands.last));
  }

  static Value and(Iterable<Value> operands) {
    return _wrapPrimitive(
        _getRaw<bool>(operands.first) && _getRaw<bool>(operands.last));
  }

  static Value or(Iterable<Value> operands) {
    return _wrapPrimitive(
        _getRaw<bool>(operands.first) || _getRaw<bool>(operands.last));
  }

  static Value assign(Iterable<Value> operands) {
    (operands.first as Variable).set(operands.last);
    return _wrapPrimitive(operands.first);
  }

  static Value addAssign(Iterable<Value> operands) {
    (operands.first as Variable).set(add(operands));
    return _wrapPrimitive(operands.first);
  }

  static Value subtractAssign(Iterable<Value> operands) {
    (operands.first as Variable).set(subtract(operands));
    return _wrapPrimitive(operands.first);
  }

  static Value multiplyAssign(Iterable<Value> operands) {
    (operands.first as Variable).set(multiply(operands));
    return _wrapPrimitive(operands.first);
  }

  static Value divideAssign(Iterable<Value> operands) {
    (operands.first as Variable).set(divide(operands));
    return _wrapPrimitive(operands.first);
  }
}

// var operators = <String, TokenOperator>{
//   '^': TokenOperator(17.0, _Operations.exponent, rightAssociative: true),
//
//   '++': TokenOperator(16.0, _Operations.preIncrement, isUnary: true),
//   '[]': TokenOperator(16.0, null),
//
//   '!': TokenOperator(15.0, _Operations.not,
//       isUnary: true, warning: 'Use "not" instead of "!".'),
//   'not': TokenOperator(15.0, _Operations.not, isUnary: true),
//   '~': TokenOperator(15.0, _Operations.bitnot, isUnary: true),
//   '->u': TokenOperator(15.0, _Operations.redirect),
//   '-u': TokenOperator(15.0, _Operations.unaryMinus, isUnary: true),
//   '@': TokenOperator(15.0, _Operations.referenceTo, isUnary: true),
//
//   '*': TokenOperator(14.0, _Operations.multiply),
//   '/': TokenOperator(14.0, _Operations.divide),
//   '%': TokenOperator(14.0, _Operations.modulus),
//
//   '+': TokenOperator(13.0, _Operations.add),
//   '-': TokenOperator(13.0, _Operations.subtract),
//
//   '<': TokenOperator(11.0, _Operations.lessThan),
//   '<=': TokenOperator(11.0, _Operations.lessThanOrEqual),
//   '>': TokenOperator(11.0, _Operations.greaterThan),
//   '>=': TokenOperator(11.0, _Operations.greaterThanEqual),
//   'as': TokenOperator(11.0, _Operations.cast),
//
//   '==': TokenOperator(10.0, _Operations.equal),
//   '!=': TokenOperator(10.0, _Operations.notEqual),
//
//   // We don't use words for bitwise operators (apart from 'xor') because there
//   //  are often many on one line, so lines would get too long. Additionally,
//   //  it is probably better to include comments that explain the operations
//   //  instead of replacing confusing code with verbose confusing code.
//   '&': TokenOperator(9.0, _Operations.bitand),
//   'xor': TokenOperator(8.0, _Operations.xor),
//   '|': TokenOperator(7.0, _Operations.bitor),
//
//   '&&': TokenOperator(6.0, _Operations.and,
//       warning: 'Use "and" instead of "&&".'),
//   'and': TokenOperator(6.0, _Operations.and),
//   '||':
//       TokenOperator(5.0, _Operations.or, warning: 'Use "or" instead of "||".'),
//   'or': TokenOperator(5.0, _Operations.or),
//
//   '->': TokenOperator(3.0, _Operations.redirect),
//   '+=': TokenOperator(3.0, _Operations.addAssign),
//   '-=': TokenOperator(3.0, _Operations.subtractAssign),
//   '*=': TokenOperator(3.0, _Operations.multiplyAssign),
//   '/=': TokenOperator(3.0, _Operations.divideAssign)
// };

// List<Token> infixToPostfix(List<Token> infix) {
//   var rpn = <Token>[];
//   var stack = <Token>[];
//
//   // Find and resolve unary operations.
//   for (var i = 0; i < infix.length; ++i) {
//     var token = infix[i];
//     if (token.isNotOperator) {
//       continue;
//     }
//
//     // We already know that "token" is an operator. If i == 0, that would make
//     //  the first thing in the input an operator, so it must be a unary operator.
//     // Also, if the previous token in the infix expression was also an operator,
//     //  then this must be a unary operator: infix only allows two operators
//     //  side-by-side if the rightmost one is a unary operator (AFAIK).
//     if (i != 0 && infix[i - 1].isNotOperator) {
//       continue;
//     }
//
//     // We only need to add a 'u' if the operator isn't already being recognised
//     //  as a unary one.
//     var needsMakingUnary = !operators[token.toString()].isUnary;
//
//     if (needsMakingUnary) {
//       var unaryString = token.toString() + 'u';
//       var unaryOperator = operators[unaryString];
//
//       if (unaryOperator != null && unaryOperator.isUnary) {
//         token = TextToken(TokenType.Symbol, unaryString);
//       } else {
//         throw InvalidSyntaxException(
//             'Operator "${token}" is not unary.', 5, token.line, token.column);
//       }
//     }
//   }
//
//   for (var token in infix) {
//     if (token.isNotOperator) {
//       rpn.add(token);
//       continue;
//     }
//
//     var operator = operators[token.toString()];
//     operator.issueWarningIfAny(token.line, token.column);
//
//     while (stack.isNotEmpty) {
//       var topToken = stack.last;
//       var topString = topToken.toString();
//
//       var isOp =
//           topToken.type == TokenType.Symbol && operators.containsKey(topString);
//
//       var topOperator = operators[topString];
//       if (!isOp ||
//           operator.precedence > topOperator.precedence ||
//           operator.precedence == topOperator.precedence &&
//               operator.rightAssociative) {
//         break;
//       }
//
//       // Move the top operator to the RPN output.
//       rpn.add(stack.removeLast());
//     }
//
//     // Push the new operator onto the stack.
//     stack.add(token);
//   }
//
//   // Move everything left in the stack to the output list.
//   while (stack.isNotEmpty) {
//     rpn.add(stack.removeLast());
//   }
//
//   return rpn;
// }
//
// var _indexingPattern = GroupPattern('[', ']');
//
// Value evaluatePostfix(List<Token> postfix) {
//   var numberStack = <Value>[];
//
//   for (var token in postfix) {
//     if (_indexingPattern.hasMatch(token)) {
//       Value result;
//
//       if (numberStack.last is ValueType) {
//         result = _Operations.createArrayType([numberStack.removeLast()]);
//       } else {
//         result = _Operations.getAtIndex([
//           numberStack.removeLast(),
//           Parse.expression(token.allTokens()).evaluate()
//         ]);
//       }
//
//       numberStack.add(result);
//
//       continue;
//     }
//
//     if (token.type == TokenType.Symbol &&
//         operators.containsKey(token.toString())) {
//       var operator = operators[token.toString()];
//
//       // Check for unary operations.
//       if (operator.isUnary) {
//         var oldTop = numberStack.removeLast();
//
//         numberStack.add(operator([oldTop]));
//
//         continue;
//       }
//
//       // Binary, so apply the operator to top two numbers in the stack.
//       var b = numberStack.removeLast();
//       var a = numberStack.removeLast();
//
//       numberStack.add(operator([a, b]));
//       continue;
//     }
//
//     numberStack.add(Parse.expression(token.allTokens()).evaluate());
//   }
//
//   if (numberStack.isEmpty) {
//     return Variable(NoType(), IntegerValue.raw(0));
//   }
//
//   if (numberStack.length > 1) {
//     // Location will be approximate.
//     throw InvalidSyntaxException('Invalid operator expression.', 1,
//         postfix.first.line, postfix.first.column);
//   }
//
//   return numberStack.last;
// }

enum _Associativity { Left, Right }

enum _Fixity { Prefix, Infix, Postfix }

class _FixOperator {
  final _Associativity associativity;
  final double precedence;
  final int operandCount;
  final _Fixity fixity;
  final Value Function(Iterable<Value> operands) operation;

  _FixOperator(this.associativity, this.precedence, this.operandCount,
      this.fixity, this.operation);
}

class ShuntingYard {
  static var yardOperators = <String, _FixOperator>{
    '.': _FixOperator(_Associativity.Left, 18.0, 2, _Fixity.Infix, null),
    '[]': _FixOperator(_Associativity.Left, 18.0, 2, _Fixity.Postfix,
        _Operations.squareBrackets),

    '++': _FixOperator(_Associativity.Left, 16.0, 1, _Fixity.Postfix,
        _Operations.preIncrement),
    '--': _FixOperator(_Associativity.Left, 16.0, 1, _Fixity.Postfix, null),

    'not': _FixOperator(
        _Associativity.Right, 15.0, 1, _Fixity.Prefix, _Operations.not),
    '~': _FixOperator(
        _Associativity.Right, 15.0, 1, _Fixity.Prefix, _Operations.bitnot),
    '+u': _FixOperator(_Associativity.Right, 15.0, 1, _Fixity.Prefix, null),
    '-u': _FixOperator(
        _Associativity.Right, 15.0, 1, _Fixity.Prefix, _Operations.unaryMinus),
    '->u': _FixOperator(
        _Associativity.Right, 15.0, 1, _Fixity.Prefix, _Operations.redirect),
    '@': _FixOperator(
        _Associativity.Right, 15.0, 1, _Fixity.Prefix, _Operations.referenceTo),

    '*': _FixOperator(
        _Associativity.Left, 14.0, 2, _Fixity.Infix, _Operations.multiply),
    '/': _FixOperator(
        _Associativity.Left, 14.0, 2, _Fixity.Infix, _Operations.divide),
    '%': _FixOperator(
        _Associativity.Left, 14.0, 2, _Fixity.Infix, _Operations.modulus),

    '+': _FixOperator(
        _Associativity.Left, 13.0, 2, _Fixity.Infix, _Operations.add),
    '-': _FixOperator(
        _Associativity.Left, 13.0, 2, _Fixity.Infix, _Operations.subtract),

    '<<': _FixOperator(_Associativity.Left, 12.0, 2, _Fixity.Infix, null),
    '>>': _FixOperator(_Associativity.Left, 12.0, 2, _Fixity.Infix, null),

    '<': _FixOperator(
        _Associativity.Left, 11.0, 2, _Fixity.Infix, _Operations.lessThan),
    '<=': _FixOperator(_Associativity.Left, 11.0, 2, _Fixity.Infix,
        _Operations.lessThanOrEqual),
    '>': _FixOperator(
        _Associativity.Left, 11.0, 2, _Fixity.Infix, _Operations.greaterThan),
    '>=': _FixOperator(_Associativity.Left, 11.0, 2, _Fixity.Infix,
        _Operations.greaterThanEqual),
    'in': _FixOperator(_Associativity.Left, 11.0, 2, _Fixity.Infix, null),
    'is': _FixOperator(_Associativity.Left, 11.0, 2, _Fixity.Infix, null),
    'as': _FixOperator(
        _Associativity.Left, 11.0, 2, _Fixity.Infix, _Operations.cast),

    '==': _FixOperator(
        _Associativity.Left, 10.0, 2, _Fixity.Infix, _Operations.equal),
    '!=': _FixOperator(
        _Associativity.Left, 10.0, 2, _Fixity.Infix, _Operations.notEqual),

    '&': _FixOperator(
        _Associativity.Left, 9.0, 2, _Fixity.Infix, _Operations.bitand),
    'xor': _FixOperator(
        _Associativity.Left, 8.0, 2, _Fixity.Infix, _Operations.xor),
    '|': _FixOperator(
        _Associativity.Left, 7.0, 2, _Fixity.Infix, _Operations.bitor),

    'and': _FixOperator(
        _Associativity.Left, 6.0, 2, _Fixity.Infix, _Operations.and),
    'or': _FixOperator(
        _Associativity.Left, 5.0, 2, _Fixity.Infix, _Operations.or),

    // Ternary here

    '->': _FixOperator(
        _Associativity.Right, 3.0, 2, _Fixity.Infix, _Operations.redirect),
    // '=': _FixOperator(
    //     _Associativity.Right, 3.0, 2, _Fixity.Infix, _Operations.assign),
    '+=': _FixOperator(
        _Associativity.Right, 3.0, 2, _Fixity.Infix, _Operations.addAssign),
    '-=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix,
        _Operations.subtractAssign),
    '*=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix,
        _Operations.multiplyAssign),
    '/=': _FixOperator(
        _Associativity.Right, 3.0, 2, _Fixity.Infix, _Operations.divideAssign),
    '%=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix, null),
    '<<=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix, null),
    '>>=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix, null),
    '&=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix, null),
    '^=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix, null),
    '|=': _FixOperator(_Associativity.Right, 3.0, 2, _Fixity.Infix, null),

    'yield': _FixOperator(_Associativity.Right, 2.0, 1, _Fixity.Prefix, null),

    '...': _FixOperator(_Associativity.Right, 1.0, 1, _Fixity.Prefix, null),
  };

  static bool isAnOperator(Token token) {
    return (token.type == TokenType.Group || token.type == TokenType.Symbol) &&
        yardOperators.containsKey(token.toString());
  }

  static List<Token> toPostfix(List<Token> infix) {
    var input = <Token>[];

    var parentheses = GroupPattern('(', ')');

    for (var token in infix) {
      if (parentheses.hasMatch(token)) {
        // Unpack the parentheses.
        input.addAll((token as GroupToken).children);
      } else {
        input.add(token);
      }
    }

    var i = 0, _i = 0;

    _FixOperator op1, op2;
    Token token, token2;

    var matched = false;

    var output = <Token>[];
    var stack = <Token>[];
    for (var _len = input.length; _i < _len; i = ++_i) {
      token = input[i];
      if (yardOperators[token.toString()] != null) {
        op1 = yardOperators[token.toString()];
        switch (op1.fixity) {
          case _Fixity.Prefix:
            stack.add(token);
            break;
          case _Fixity.Postfix:
            output.add(token);
            break;
          case _Fixity.Infix:
            while (stack.length > 0) {
              token2 = stack[stack.length - 1];
              if (yardOperators[token2.toString()] != null) {
                op2 = yardOperators[token2.toString()];
                if (op1.associativity == _Associativity.Left &&
                        op1.precedence <= op2.precedence ||
                    op1.precedence < op2.precedence) {
                  output.add(stack.removeLast());
                  continue;
                }
              }
              break;
            }
            stack.add(token);
            break;
          // default:
          //   return new Error("Operator " + token + " at index " + i + " has invalid fix property: " + op1.fix + ", found in: " + (input.join('')));
        }
        // } else if (functions[token] != null) {
        //   stack.add(token);
      } else if (TokenPattern(string: ',', type: TokenType.Symbol)
          .hasMatch(token)) {
        while (stack.length > 0) {
          token = stack[stack.length - 1];
          if (TokenPattern(string: '(', type: TokenType.Symbol)
              .notMatch(token)) {
            output.add(token);
            stack.removeLast();
          } else {
            matched = true;
            break;
          }
        }
        if (!matched) {
          throw Exception('no left paren');
          // return new Error("Parse error, no matching left paren for function at index " + i + " of " + (input.join('')));
        }
      } else if (TokenPattern(string: '(', type: TokenType.Symbol)
          .hasMatch(token)) {
        stack.add(token);
      } else if (TokenPattern(string: ')', type: TokenType.Symbol)
          .hasMatch(token)) {
        while (stack.length > 0) {
          token = stack.removeLast();
          if (TokenPattern(string: '(', type: TokenType.Symbol)
              .hasMatch(token)) {
            matched = true;
            break;
          } else {
            output.add(token);
          }
        }
        if (!matched) {
          throw Exception('no left paren');
          // return new Error("Parse error, no matching left paren at index " + i + " of " + (input.join('')));
        }
        // if (stack.length > 0 && (functions[stack[stack.length - 1]] != null)) {
        //   output.add(stack.pop());
        // }
        // } else if (typeof token === 'number') {
        //   output.add(token);
      } else {
        output.add(token);
        // return new Error("Parse error, token " + token + " is not a known operator, paren, or number type at index " + i + " of " + (input.join('')));
      }
    }
    while (stack.length > 0) {
      token = stack.removeLast();
      if (TokenPattern(string: '(', type: TokenType.Symbol).hasMatch(token) ||
          TokenPattern(string: ')', type: TokenType.Symbol).hasMatch(token)) {
        throw Exception('mismatched parens');
        // return new Error("Parse error, mismatched parens, found extra " + token + " in " + (input.join('')) + ", operators left in stack: " + (stack.join(' ')));
      } else {
        output.add(token);
      }
    }

    return output;
  }

  static Value evaluate(List<Token> input) {
    var numberStack = <Value>[];

    var postfix = <Token>[];

    for (var token in input) {
      if (isAnOperator(token) && token is GroupToken) {
        var separatedTokens = <Token>[
          TextToken(TokenType.Symbol, '('),
          TextToken(TokenType.Symbol, ')')
        ];

        separatedTokens.insertAll(1, token.middle());

        postfix.add(GroupToken(separatedTokens));
        postfix.add(GroupToken([token.children.first, token.children.last]));
      } else {
        postfix.add(token);
      }
    }

    for (var token in postfix) {
      if (isAnOperator(token)) {
        var operator = yardOperators[token.toString()];

        var opCount = operator.operandCount;
        // if (opCount > numberStack.length) {
        //   throw RuntimeError('Not enough operands for "$token"!');
        // }

        var args = List<Value>.filled(min(opCount, numberStack.length), null);

        for (var i = min(opCount, numberStack.length); i >= 1; --i) {
          args[i - 1] = numberStack.removeLast();
        }

        numberStack.add(operator.operation(args));
        continue;
      }

      numberStack.add(Parse.expression(token.allTokens()).evaluate());
    }

    if (numberStack.isEmpty) {
      return Variable(NoType(), IntegerValue.raw(0));
    }

    if (numberStack.length > 1) {
      // Location will be approximate.
      throw InvalidSyntaxException('Invalid operator expression.', 1,
          postfix.first.line, postfix.first.column);
    }

    return numberStack.last;
  }
}
