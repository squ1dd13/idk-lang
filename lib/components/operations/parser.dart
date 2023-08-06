import 'dart:math';

import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/handle.dart';
import 'package:language/runtime/type.dart';
import 'package:language/runtime/value.dart';

import 'operations.dart';

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
    if (warning.isEmpty ?? true) {
      return;
    }

    print('Warning: ($line, $column) $warning');
  }

  Value call(Iterable<Handle> operands) {
    return _implementation(operands);
  }
}

enum _Side { Left, Right }

enum Fix { Pre, In, Post }

class _Operator {
  final _Side associativity;
  final double precedence;
  final int operandCount;
  final Fix fixity;
  final Handle? Function(Iterable<Handle?> operands)? operation;

  _Operator(this.associativity, this.precedence, this.operandCount, this.fixity,
      this.operation);
}

class ShuntingYard {
  static var operators = <String, _Operator>{
    ':': _Operator(_Side.Left, 19.0, 2, Fix.In, Operations.colon),

    '.': _Operator(_Side.Left, 18.0, 2, Fix.In, Operations.dot),
    '[]': _Operator(_Side.Left, 18.0, 1, Fix.Post, Operations.subscript),

    // Only post at the moment, so '++n' doesn't work.
    '++': _Operator(_Side.Left, 16.0, 1, Fix.Post, Operations.increment),
    '--': _Operator(_Side.Left, 16.0, 1, Fix.Post, null),

    'not': _Operator(_Side.Right, 15.0, 1, Fix.Pre, Operations.not),
    '~': _Operator(_Side.Right, 15.0, 1, Fix.Pre, Operations.bitnot),
    '-u': _Operator(_Side.Right, 15.0, 1, Fix.Pre, Operations.unaryMinus),
    '->': _Operator(_Side.Right, 15.0, 1, Fix.Pre, Operations.inlineDirection),
    '@': _Operator(_Side.Right, 15.0, 1, Fix.Pre, Operations.referenceTo),
    '#': _Operator(_Side.Right, 15.0, 1, Fix.Pre, Operations.subscript),

    '*': _Operator(_Side.Left, 14.0, 2, Fix.In, Operations.multiply),
    '/': _Operator(_Side.Left, 14.0, 2, Fix.In, Operations.divide),
    '%': _Operator(_Side.Left, 14.0, 2, Fix.In, Operations.modulus),

    '+': _Operator(_Side.Left, 13.0, 2, Fix.In, Operations.add),
    '-': _Operator(_Side.Left, 13.0, 2, Fix.In, Operations.subtract),

    '<<': _Operator(_Side.Left, 12.0, 2, Fix.In, null),
    '>>': _Operator(_Side.Left, 12.0, 2, Fix.In, null),

    '<': _Operator(_Side.Left, 11.0, 2, Fix.In, Operations.lessThan),
    '<=': _Operator(_Side.Left, 11.0, 2, Fix.In, Operations.lessThanOrEqual),
    '>': _Operator(_Side.Left, 11.0, 2, Fix.In, Operations.greaterThan),
    '>=': _Operator(_Side.Left, 11.0, 2, Fix.In, Operations.greaterThanEqual),
    'in': _Operator(_Side.Left, 11.0, 2, Fix.In, null),
    'is': _Operator(_Side.Left, 11.0, 2, Fix.In, null),
    'as': _Operator(_Side.Left, 11.0, 2, Fix.In, Operations.cast),

    '==': _Operator(_Side.Left, 10.0, 2, Fix.In, Operations.equal),
    '!=': _Operator(_Side.Left, 10.0, 2, Fix.In, Operations.notEqual),

    '&': _Operator(_Side.Left, 9.0, 2, Fix.In, Operations.bitand),
    'xor': _Operator(_Side.Left, 8.0, 2, Fix.In, Operations.xor),
    '|': _Operator(_Side.Left, 7.0, 2, Fix.In, Operations.bitor),

    // We use words for logic operators so that conditions read more fluently.
    // We don't do this for bitwise operators because words are longer and there
    //  are typically many bitwise operators on one line, so lines would get
    //  very long.
    'and': _Operator(_Side.Left, 6.0, 2, Fix.In, Operations.and),
    'or': _Operator(_Side.Left, 5.0, 2, Fix.In, Operations.or),

    // Ternary here

    '=': _Operator(_Side.Right, 3.0, 2, Fix.In, Operations.assign),
    '+=': _Operator(_Side.Right, 3.0, 2, Fix.In, Operations.addAssign),
    '-=': _Operator(_Side.Right, 3.0, 2, Fix.In, Operations.subtractAssign),
    '*=': _Operator(_Side.Right, 3.0, 2, Fix.In, Operations.multiplyAssign),
    '/=': _Operator(_Side.Right, 3.0, 2, Fix.In, Operations.divideAssign),

    'yield': _Operator(_Side.Right, 2.0, 1, Fix.Pre, null),

    '...': _Operator(_Side.Right, 1.0, 1, Fix.Pre, null),
  };

  static var _addedHidden = false;

  static void _addHiddenOperators() {
    if (_addedHidden) {
      return;
    }

    // "call" here is actually for the group ("call", "") so we can still
    //  package arguments but using a different group from "()".
    operators['call'] = _Operator(_Side.Left, 18.0, 1, Fix.In, null);
    _addedHidden = true;
  }

  static bool isOperator(Token token) {
    // We need to check if the token is actually an operator token, because
    //  just finding an operator for token.toString() would mean string literals
    //  would match ('"=="' would be the same as '==').
    return (token.type == TokenType.Group || token.type == TokenType.Symbol) &&
        operators.containsKey(token.toString());
  }

  static _Operator? getOperator(Token token) {
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
      if (operator!.fixity == Fix.Pre) {
        stack.add(token);
        continue;
      }

      // Postfix operators go directly to the output, since they are
      //  already in RPN (which is pure postfix).
      if (operator.fixity == Fix.Post) {
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

  static Handle? evaluate(List<Token> tokens) {
    var numberStack = <Handle?>[];

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

      var operands = List<Handle?>.filled(minOperands, null);

      // Pop each operand off the number stack.
      for (var i = minOperands; i >= 1; --i) {
        operands[i - 1] = numberStack.removeLast();
      }

      // Carry out the operation and push the result onto the stack.
      numberStack.add(Operations.getOperation(token)!(operands));

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
