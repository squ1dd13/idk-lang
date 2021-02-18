import 'dart:math';

import 'package:language/lexer.dart';
import 'package:language/parser/parser.dart';
import 'package:language/parser/util.dart';
import 'package:language/runtime/abstract.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/type.dart';

class OperatorExpression implements Expression {
  List<Token> _tokens;

  OperatorExpression(TokenStream tokens) {
    _tokens = infixToPostfix(tokens.takeUntilSemicolon());
  }

  @override
  Evaluable evaluate() {
    return evaluatePostfix(_tokens);
  }
}

class TokenOperator implements Function {
  double precedence;
  bool rightAssociative;
  bool isUnary;
  String warning;
  Value Function(Iterable<Value> operands) _implementation;

  TokenOperator(this.precedence, this._implementation,
      {this.rightAssociative = false, this.isUnary = false, this.warning = ''});

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

var operators = <String, TokenOperator>{
  '^': TokenOperator(17.0, _Operations.exponent, rightAssociative: true),

  '++': TokenOperator(16.0, _Operations.preIncrement, isUnary: true),

  '!': TokenOperator(15.0, _Operations.not,
      isUnary: true, warning: 'Use "not" instead of "!".'),
  'not': TokenOperator(15.0, _Operations.not, isUnary: true),
  '~': TokenOperator(15.0, _Operations.bitnot, isUnary: true),
  '->u': TokenOperator(15.0, _Operations.redirect),
  '-u': TokenOperator(15.0, _Operations.unaryMinus, isUnary: true),
  // '@': TokenOperator(15.0, _Operations.referenceTo, isUnary: true),

  '*': TokenOperator(14.0, _Operations.multiply),
  '/': TokenOperator(14.0, _Operations.divide),
  '%': TokenOperator(14.0, _Operations.modulus),

  '+': TokenOperator(13.0, _Operations.add),
  '-': TokenOperator(13.0, _Operations.subtract),

  '<': TokenOperator(11.0, _Operations.lessThan),
  '<=': TokenOperator(11.0, _Operations.lessThanOrEqual),
  '>': TokenOperator(11.0, _Operations.greaterThan),
  '>=': TokenOperator(11.0, _Operations.greaterThanEqual),
  'as': TokenOperator(11.0, _Operations.cast),

  '==': TokenOperator(10.0, _Operations.equal),
  '!=': TokenOperator(10.0, _Operations.notEqual),

  // We don't use words for bitwise operators (apart from 'xor') because there
  //  are often many on one line, so lines would get too long. Additionally,
  //  it is probably better to include comments that explain the operations
  //  instead of replacing confusing code with verbose confusing code.
  '&': TokenOperator(9.0, _Operations.bitand),
  'xor': TokenOperator(8.0, _Operations.xor),
  '|': TokenOperator(7.0, _Operations.bitor),

  '&&': TokenOperator(6.0, _Operations.and,
      warning: 'Use "and" instead of "&&".'),
  'and': TokenOperator(6.0, _Operations.and),
  '||':
      TokenOperator(5.0, _Operations.or, warning: 'Use "or" instead of "||".'),
  'or': TokenOperator(5.0, _Operations.or),

  '->': TokenOperator(3.0, _Operations.redirect),
  '+=': TokenOperator(3.0, _Operations.addAssign),
  '-=': TokenOperator(3.0, _Operations.subtractAssign),
  '*=': TokenOperator(3.0, _Operations.multiplyAssign),
  '/=': TokenOperator(3.0, _Operations.divideAssign)
};

List<Token> infixToPostfix(List<Token> infix) {
  bool isOperator(Token token) {
    return token.type == TokenType.Symbol &&
        operators.containsKey(token.toString());
  }

  var rpn = <Token>[];
  var stack = <Token>[];

  // Find and resolve unary operations.
  for (var i = 0; i < infix.length; ++i) {
    var token = infix[i];
    if (!isOperator(token)) {
      continue;
    }

    // We already know that "token" is an operator. If i == 0, that would make
    //  the first thing in the input an operator, so it must be a unary operator.
    // Also, if the previous token in the infix expression was also an operator,
    //  then this must be a unary operator: infix only allows two operators
    //  side-by-side if the rightmost one is a unary operator (AFAIK).
    if (i != 0 && !isOperator(infix[i - 1])) {
      continue;
    }

    // We only need to add a 'u' if the operator isn't already being recognised
    //  as a unary one.
    var needsMakingUnary = !operators[token.toString()].isUnary;

    if (needsMakingUnary) {
      var unaryString = token.toString() + 'u';
      var unaryOperator = operators[unaryString];

      if (unaryOperator != null && unaryOperator.isUnary) {
        token = TextToken(TokenType.Symbol, unaryString);
      } else {
        throw InvalidSyntaxException(
            'Operator "${token}" is not unary.', 5, token.line, token.column);
      }
    }
  }

  for (var token in infix) {
    if (!isOperator(token)) {
      rpn.add(token);
      continue;
    }

    var operator = operators[token.toString()];
    operator.issueWarningIfAny(token.line, token.column);

    while (stack.isNotEmpty) {
      var topToken = stack.last;
      var topString = topToken.toString();

      var isOp =
          topToken.type == TokenType.Symbol && operators.containsKey(topString);

      var topOperator = operators[topString];
      if (!isOp ||
          operator.precedence > topOperator.precedence ||
          operator.precedence == topOperator.precedence &&
              operator.rightAssociative) {
        break;
      }

      // Move the top operator to the RPN output.
      rpn.add(stack.removeLast());
    }

    // Push the new operator onto the stack.
    stack.add(token);
  }

  // Move everything left in the stack to the output list.
  while (stack.isNotEmpty) {
    rpn.add(stack.removeLast());
  }

  return rpn;
}

Value evaluatePostfix(List<Token> postfix) {
  var numberStack = <Value>[];

  for (var token in postfix) {
    if (token.type == TokenType.Symbol &&
        operators.containsKey(token.toString())) {
      var operator = operators[token.toString()];
      // Check for unary operations.
      if (operator.isUnary) {
        var oldTop = numberStack.removeLast();

        numberStack.add(operator([oldTop]));

        continue;
      }

      // Binary, so apply the operator to top two numbers in the stack.
      var b = numberStack.removeLast();
      var a = numberStack.removeLast();

      numberStack.add(operator([a, b]));
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
