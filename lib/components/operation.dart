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

  static Value increment(Iterable<Value> operands) {
    var oldValue = _wrapPrimitive(_getRaw(operands.first));
    (operands.first as Variable)
        .set(_wrapPrimitive(_getRaw(operands.first) + 1));

    return oldValue;
  }

  // Handles uses of '[]' for declaring array types and for accessing
  //  values by key/index in collections.
  static Value squareBrackets(Iterable<Value> operands) {
    // "Type[]" is an array of values of type 'Type'.
    if (operands.first is ValueType) {
      return ArrayType(operands.first as ValueType);
    }

    // "something[n]" is an access to the nth item in the 'something'.
    return operands.first.at(operands.last);
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

enum _Side { Left, Right }

enum _Fix { Pre, In, Post }

class _Operator {
  final _Side associativity;
  final double precedence;
  final int operandCount;
  final _Fix fixity;
  final Value Function(Iterable<Value> operands) operation;

  _Operator(this.associativity, this.precedence, this.operandCount, this.fixity,
      this.operation);
}

class ShuntingYard {
  static var operators = <String, _Operator>{
    '.': _Operator(_Side.Left, 18.0, 2, _Fix.In, null),
    '[]': _Operator(_Side.Left, 18.0, 2, _Fix.Post, _Operations.squareBrackets),

    // Only post at the moment, so '++n' doesn't work.
    '++': _Operator(_Side.Left, 16.0, 1, _Fix.Post, _Operations.increment),
    '--': _Operator(_Side.Left, 16.0, 1, _Fix.Post, null),

    'not': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.not),
    '~': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.bitnot),
    '-u': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.unaryMinus),
    '->u': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.redirect),
    '@': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.referenceTo),

    '*': _Operator(_Side.Left, 14.0, 2, _Fix.In, _Operations.multiply),
    '/': _Operator(_Side.Left, 14.0, 2, _Fix.In, _Operations.divide),
    '%': _Operator(_Side.Left, 14.0, 2, _Fix.In, _Operations.modulus),

    '+': _Operator(_Side.Left, 13.0, 2, _Fix.In, _Operations.add),
    '-': _Operator(_Side.Left, 13.0, 2, _Fix.In, _Operations.subtract),

    '<<': _Operator(_Side.Left, 12.0, 2, _Fix.In, null),
    '>>': _Operator(_Side.Left, 12.0, 2, _Fix.In, null),

    '<': _Operator(_Side.Left, 11.0, 2, _Fix.In, _Operations.lessThan),
    '<=': _Operator(_Side.Left, 11.0, 2, _Fix.In, _Operations.lessThanOrEqual),
    '>': _Operator(_Side.Left, 11.0, 2, _Fix.In, _Operations.greaterThan),
    '>=': _Operator(_Side.Left, 11.0, 2, _Fix.In, _Operations.greaterThanEqual),
    'in': _Operator(_Side.Left, 11.0, 2, _Fix.In, null),
    'is': _Operator(_Side.Left, 11.0, 2, _Fix.In, null),
    'as': _Operator(_Side.Left, 11.0, 2, _Fix.In, _Operations.cast),

    '==': _Operator(_Side.Left, 10.0, 2, _Fix.In, _Operations.equal),
    '!=': _Operator(_Side.Left, 10.0, 2, _Fix.In, _Operations.notEqual),

    '&': _Operator(_Side.Left, 9.0, 2, _Fix.In, _Operations.bitand),
    'xor': _Operator(_Side.Left, 8.0, 2, _Fix.In, _Operations.xor),
    '|': _Operator(_Side.Left, 7.0, 2, _Fix.In, _Operations.bitor),

    // We use words for logic operators so that conditions read more fluently.
    // We don't do this for bitwise operators because words are longer and there
    //  are typically many bitwise operators on one line, so lines would get
    //  very long.
    'and': _Operator(_Side.Left, 6.0, 2, _Fix.In, _Operations.and),
    'or': _Operator(_Side.Left, 5.0, 2, _Fix.In, _Operations.or),

    // Ternary here

    '->': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.redirect),
    '+=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.addAssign),
    '-=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.subtractAssign),
    '*=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.multiplyAssign),
    '/=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.divideAssign),

    'yield': _Operator(_Side.Right, 2.0, 1, _Fix.Pre, null),

    '...': _Operator(_Side.Right, 1.0, 1, _Fix.Pre, null),
  };

  static bool isOperator(Token token) {
    // We need to check if the token is actually an operator token, because
    //  just finding an operator for token.toString() would mean string literals
    //  would match ('"=="' would be the same as '==').
    return (token.type == TokenType.Group || token.type == TokenType.Symbol) &&
        operators.containsKey(token.toString());
  }

  static _Operator _getOperator(Token token) {
    if (isOperator(token)) {
      return operators[token.toString()];
    }

    return null;
  }

  static List<Token> toPostfix(List<Token> input) {
    var output = <Token>[];
    var stack = <Token>[];

    for (var token in input) {
      var operator = _getOperator(token);

      if (operator == null) {
        output.add(token);
        continue;
      }

      // Prefix operators go on the stack.
      if (operator.fixity == _Fix.Pre) {
        stack.add(token);
        continue;
      }

      // Postfix operators go directly to the output, since they are
      //  already in RPN (which is pure postfix).
      if (operator.fixity == _Fix.Post) {
        output.add(token);
        continue;
      }

      // Move from the operator stack to the output until the stack is empty
      //  or until we encounter something that isn't ready to be moved yet.
      while (stack.isNotEmpty) {
        var stackOperator = _getOperator(stack.last);

        if (stackOperator == null) {
          break;
        }

        var precedence = stackOperator.precedence;

        if (operator.associativity == _Side.Left &&
                operator.precedence <= precedence ||
            operator.precedence < precedence) {
          output.add(stack.removeLast());
          continue;
        }

        break;
      }

      stack.add(token);
    }

    while (stack.isNotEmpty) {
      var token = stack.removeLast();
      output.add(token);
    }

    return output;
  }

  static Value evaluate(List<Token> tokens) {
    var numberStack = <Value>[];

    // The same as 'tokens' but with group operators (such as '[]') split
    //  into multiple tokens. 'x[0]' would become 'x (0) []', with '0' being
    //  the second operand for the '[]' operator.
    var postfix = <Token>[];

    for (var token in tokens) {
      if (isOperator(token) && token is GroupToken) {
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
      var operator = _getOperator(token);

      if (operator == null) {
        var expression = Parse.expression(token.allTokens());
        numberStack.add(expression.evaluate());

        continue;
      }

      // The smaller of the number of operands we want and the number we
      //  have available. This is important for things like '[]', where
      //  it can take either 1 or 2 operands.
      var minOperands = min(operator.operandCount, numberStack.length);

      var operands = List<Value>.filled(minOperands, null);

      // Pop each operand off the number stack.
      for (var i = minOperands; i >= 1; --i) {
        operands[i - 1] = numberStack.removeLast();
      }

      // Carry out the operation and push the result onto the stack.
      numberStack.add(operator.operation(operands));

      continue;
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
