import 'dart:math';

import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/function.dart';
import 'package:language/runtime/handle.dart';
import 'package:language/runtime/primitive.dart';
import 'package:language/runtime/type.dart';
import 'package:language/runtime/value.dart';

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
      var notOperator = tokens.current().isNotOperator &&
          GroupPattern('(', ')').notMatch(tokens.current());

      if (notOperator && lastWasOperand) {
        break;
      }

      found.add(tokens.take());
      lastWasOperand = notOperator;
    }

    if (found.length == 1 && found[0].type == TokenType.Symbol) {
      found.first.throwSyntax('Invalid expression! Found only one symbol.', 1);
    }

    _tokens = found;
    _preprocess();
  }

  void _preprocess() {
    _findHiddenUnaryOperators();
    _stringifyMemberAccess();
    _tokens = ShuntingYard.toPostfix(_tokens);
  }

  void _findHiddenUnaryOperators() {
    const minusPattern = TokenPattern(string: '-', type: TokenType.Symbol);

    for (var i = 0; i < _tokens.length; ++i) {
      if (minusPattern.hasMatch(_tokens[i])) {
        var isUnary = false;

        if (i == 0) {
          isUnary = true;
        } else {
          var previousOperator = ShuntingYard.getOperator(_tokens[i - 1]);

          if (previousOperator != null && previousOperator.fixity == _Fix.In) {
            isUnary = true;
          }
        }

        if (isUnary) {
          _tokens[i] = TextToken(TokenType.Symbol, '-u');
        }
      }
    }
  }

  void _stringifyMemberAccess() {
    var nextIsMember = false;
    var output = <Token>[];

    const dotPattern = TokenPattern(string: '.', type: TokenType.Symbol);

    for (var token in _tokens) {
      if (nextIsMember) {
        if (token.type != TokenType.Name) {
          token.throwSyntax('"." operator must precede a valid name.', 10);
        }

        token.type = TokenType.String;
        nextIsMember = false;
      } else {
        nextIsMember = dotPattern.hasMatch(token);
      }

      output.add(token);
    }

    _tokens = output;
  }

  @override
  Handle evaluate() {
    return ShuntingYard.evaluate(_tokens);
  }
}

class TokenOperator implements Function {
  double precedence;
  bool rightAssociative;
  bool isUnary;
  String warning;
  final Value Function(Iterable<Handle> operands) _implementation;

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

  Value call(Iterable<Handle> operands) {
    return _implementation(operands);
  }
}

/// Implements the operators. For many, we can just pass through to Dart's
/// operators, although there are some where we have to add extra behaviour.
class _Operations {
  static dynamic _getRaw<T>(Handle v) {
    var value = v.value;

    if (T == bool) {
      return (_getRaw<int>(v) != 0 ? true : false);
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
    bool: (v) => BooleanValue(v),
    double: (v) => IntegerValue.raw((v as double).truncate()),
  };

  /// Take a value of unknown type and convert it to an appropriately typed
  /// [PrimitiveValue].
  static T _wrapPrimitive<T>(dynamic value) {
    var conversion = _wrapConversions[value.runtimeType];

    if (conversion == null) {
      throw RuntimeError('Unable to wrap value of type "${value.runtimeType}" '
          'in any primitive.');
    }

    return (T == Handle) ? conversion(value).createHandle() : conversion(value);
  }

  static Handle increment(Iterable<Handle> operands) {
    var oldValue = _wrapPrimitive<Value>(_getRaw(operands.first));

    operands.first.value = _wrapPrimitive(_getRaw(operands.first) + 1);

    return oldValue.createHandle();
  }

  static Handle dot(Iterable<Handle> operands) {
    return operands.first.value.dot(operands.last.value.toString());
  }

  // Handles uses of '[]' for declaring array types and for accessing
  //  values by key/index in collections.
  static Handle subscript(Iterable<Handle> operands) {
    // "Type[]" is an array of values of type 'Type'.
    if (operands.first.value is ValueType) {
      return ArrayType(operands.first.value as ValueType).createHandle();
    }

    // "something[n]" is an access to the nth item in the 'something'.
    return operands.first.value.at(operands.last.value);
  }

  static Handle not(Iterable<Handle> operands) {
    return _wrapPrimitive(_getRaw<int>(operands.first) != 0 ? 0 : 1);
  }

  static Handle bitnot(Iterable<Handle> operands) {
    return _wrapPrimitive(~_getRaw<int>(operands.first));
  }

  static Handle inlineDirection(Iterable<Handle> operands) {
    return Handle.reference(operands.first);
  }

  static Handle unaryMinus(Iterable<Handle> operands) {
    return _wrapPrimitive(-_getRaw(operands.first));
  }

  static Handle referenceTo(Iterable<Handle> operands) {
    return ReferenceType.to(operands.first.value as ValueType).createHandle();
  }

  static Handle multiply(Iterable<Handle> operands) {
    return _wrapPrimitive(_getRaw(operands.first) * _getRaw(operands.last));
  }

  static Handle divide(Iterable<Handle> operands) {
    return _wrapPrimitive(_getRaw(operands.first) / _getRaw(operands.last));
  }

  static Handle modulus(Iterable<Handle> operands) {
    return _wrapPrimitive(_getRaw(operands.first) % _getRaw(operands.last));
  }

  static Handle add(Iterable<Handle> operands) {
    return _wrapPrimitive(_getRaw(operands.first) + _getRaw(operands.last));
  }

  static Handle subtract(Iterable<Handle> operands) {
    return _wrapPrimitive(_getRaw(operands.first) - _getRaw(operands.last));
  }

  static Handle lessThan(Iterable<Handle> operands) {
    return _wrapPrimitive(operands.first.lessThan(operands.last));
  }

  static Handle lessThanOrEqual(Iterable<Handle> operands) {
    return _wrapPrimitive(operands.first.lessThanOrEqualTo(operands.last));
  }

  static Handle greaterThan(Iterable<Handle> operands) {
    return _wrapPrimitive(operands.first.greaterThan(operands.last));
  }

  static Handle greaterThanEqual(Iterable<Handle> operands) {
    return _wrapPrimitive(operands.first.greaterThanOrEqualTo(operands.last));
  }

  static Handle cast(Iterable<Handle> operands) {
    return operands.first.convertHandleTo(operands.last.value as ValueType);
  }

  static Handle equal(Iterable<Handle> operands) {
    return _wrapPrimitive(operands.first.equals(operands.last));
  }

  static Handle notEqual(Iterable<Handle> operands) {
    return _wrapPrimitive(operands.first.notEquals(operands.last));
  }

  static Handle bitand(Iterable<Handle> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first) & _getRaw<int>(operands.last));
  }

  static Handle xor(Iterable<Handle> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first) ^ _getRaw<int>(operands.last));
  }

  static Handle bitor(Iterable<Handle> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first) | _getRaw<int>(operands.last));
  }

  static Handle and(Iterable<Handle> operands) {
    return _wrapPrimitive(
        _getRaw<bool>(operands.first) && _getRaw<bool>(operands.last));
  }

  static Handle or(Iterable<Handle> operands) {
    return _wrapPrimitive(
        _getRaw<bool>(operands.first) || _getRaw<bool>(operands.last));
  }

  static Handle addAssign(Iterable<Handle> operands) {
    operands.first.value = add(operands).value;
    return _wrapPrimitive(operands.first);
  }

  static Handle subtractAssign(Iterable<Handle> operands) {
    operands.first.value = subtract(operands).value;
    return _wrapPrimitive(operands.first);
  }

  static Handle multiplyAssign(Iterable<Handle> operands) {
    operands.first.value = multiply(operands).value;
    return _wrapPrimitive(operands.first);
  }

  static Handle divideAssign(Iterable<Handle> operands) {
    operands.first.value = divide(operands).value;
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
  final Handle Function(Iterable<Handle> operands) operation;

  _Operator(this.associativity, this.precedence, this.operandCount, this.fixity,
      this.operation);
}

class ShuntingYard {
  static var operators = <String, _Operator>{
    '.': _Operator(_Side.Left, 18.0, 2, _Fix.In, _Operations.dot),
    '[]': _Operator(_Side.Left, 18.0, 1, _Fix.Post, _Operations.subscript),

    // Only post at the moment, so '++n' doesn't work.
    '++': _Operator(_Side.Left, 16.0, 1, _Fix.Post, _Operations.increment),
    '--': _Operator(_Side.Left, 16.0, 1, _Fix.Post, null),

    'not': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.not),
    '~': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.bitnot),
    '-u': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.unaryMinus),
    '->':
        _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.inlineDirection),
    '@': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.referenceTo),
    '#': _Operator(_Side.Right, 15.0, 1, _Fix.Pre, _Operations.subscript),

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

    '+=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.addAssign),
    '-=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.subtractAssign),
    '*=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.multiplyAssign),
    '/=': _Operator(_Side.Right, 3.0, 2, _Fix.In, _Operations.divideAssign),

    'yield': _Operator(_Side.Right, 2.0, 1, _Fix.Pre, null),

    '...': _Operator(_Side.Right, 1.0, 1, _Fix.Pre, null),
  };

  static var _addedHidden = false;

  static void _addHiddenOperators() {
    if (_addedHidden) {
      return;
    }

    // "call" here is actually for the group ("call", "") so we can still
    //  package arguments but using a different group from "()".
    operators['call'] = _Operator(_Side.Left, 18.0, 1, _Fix.In, null);
    _addedHidden = true;
  }

  static bool isOperator(Token token) {
    // We need to check if the token is actually an operator token, because
    //  just finding an operator for token.toString() would mean string literals
    //  would match ('"=="' would be the same as '==').
    return (token.type == TokenType.Group || token.type == TokenType.Symbol) &&
        operators.containsKey(token.toString());
  }

  static _Operator getOperator(Token token) {
    if (isOperator(token)) {
      return operators[token.toString()];
    }

    return null;
  }

  static List<Token> toPostfix(List<Token> infix) {
    _addHiddenOperators();

    var output = <Token>[];
    var stack = <Token>[];

    var previousWasOperand = false;

    for (var token in infix) {
      var wasOperand = previousWasOperand;
      previousWasOperand = false;

      var operator = getOperator(token);

      if (operator == null) {
        if (wasOperand && GroupPattern('(', ')').hasMatch(token)) {
          var group = token as GroupToken;
          group.children.first = TextToken(TokenType.Symbol, 'call');
          group.children.last = TextToken(TokenType.Symbol, '');

          operator = getOperator(token);
        } else {
          previousWasOperand = true;

          output.add(token);
          continue;
        }
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
        previousWasOperand = true;
        continue;
      }

      // Move from the operator stack to the output until the stack is empty
      //  or until we encounter something that isn't ready to be moved yet.
      while (stack.isNotEmpty) {
        var stackOperator = getOperator(stack.last);

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

  static Handle Function(Iterable<Handle>) _getOperation(Token token) {
    var callPattern = GroupPattern('call', '');
    var subscriptPattern = GroupPattern('[', ']');

    if (callPattern.notMatch(token) && subscriptPattern.notMatch(token)) {
      return operators[token.toString()].operation;
    }

    if (subscriptPattern.hasMatch(token)) {
      var keyExpression = Parse.expression(token.allTokens());

      return (operands) {
        var key = keyExpression.evaluate();
        return operands.first.value.at(key.value);
      };
    }

    // Call pattern.
    var argumentGroup = token as GroupToken;
    var argumentSegments = Parse.split(argumentGroup.contents(),
        TokenPattern(string: ',', type: TokenType.Symbol));

    var arguments = <Expression>[];
    for (var segment in argumentSegments) {
      arguments.add(Parse.expression(segment));
    }

    return (operands) {
      var value = operands.first.value;

      // We only get one operand, and that's the thing being called.
      if (!(value is FunctionValue)) {
        throw Exception('Cannot call non-function "$value"!');
      }

      var functionValue = value as FunctionValue;
      var parameters = functionValue.parameters;

      var argumentsArray = <Handle>[];
      for (var expression in arguments) {
        argumentsArray.add(expression.evaluate());
      }

      if (argumentsArray.length != parameters.length) {
        throw Exception(
            'Incorrect number of arguments in call to function "$value"! '
            '(Expected ${parameters.length}, got ${argumentsArray.length}.)');
      }

      // Map the arguments to their names.
      var mappedArguments = <String, Handle>{};
      var parameterNames = parameters.keys.toList();

      for (var i = 0; i < argumentsArray.length; ++i) {
        mappedArguments[parameterNames[i]] = argumentsArray[i];
      }

      return functionValue.call(mappedArguments);
    };
  }

  static Handle evaluate(List<Token> tokens) {
    var numberStack = <Handle>[];

    for (var token in tokens) {
      var operator = getOperator(token);

      if (operator == null) {
        // Allow initialiser lists.
        var isBraceGroup = GroupPattern('{', '}').hasMatch(token);
        var expression =
            Parse.expression(isBraceGroup ? [token] : token.allTokens());

        numberStack.add(expression.evaluate());

        continue;
      }

      // The smaller of the number of operands we want and the number we
      //  have available. This is important for things like '[]', where
      //  it can take either 1 or 2 operands.
      var minOperands = min(operator.operandCount, numberStack.length);

      var operands = List<Handle>.filled(minOperands, null);

      // Pop each operand off the number stack.
      for (var i = minOperands; i >= 1; --i) {
        operands[i - 1] = numberStack.removeLast();
      }

      // Carry out the operation and push the result onto the stack.
      numberStack.add(_getOperation(token)(operands));

      continue;
    }

    if (numberStack.isEmpty) {
      return NullType.nullHandle();
    }

    if (numberStack.length > 1) {
      // Location will be approximate.
      throw InvalidSyntaxException('Invalid operator expression.', 1,
          tokens.first.line, tokens.first.column);
    }

    return numberStack.last;
  }
}
