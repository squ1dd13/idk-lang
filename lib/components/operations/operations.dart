import 'package:language/components/operations/parser.dart';
import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/function.dart';
import 'package:language/runtime/handle.dart';
import 'package:language/runtime/primitive.dart';
import 'package:language/runtime/type.dart';
import 'package:language/runtime/value.dart';

/// Implements the operators. For many, we can just pass through to Dart's
/// operators, although there are some where we have to add extra behaviour.
class Operations {
  static dynamic _getRaw<T>(Handle v) {
    var value = v.value;

    if (T == bool) {
      return (_getRaw<int>(v) != 0 ? true : false);
    }

    if (value.type!.equals(PrimitiveType.integer)) {
      return (value as IntegerValue).rawValue;
    }

    // TODO: We need a mustConvertTo here.
    return ((value as PrimitiveValue).rawValue as T?);
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

    return (T == Handle)
        ? conversion(value).createHandle() as T
        : conversion(value) as T;
  }

  static Handle increment(Iterable<Handle?> operands) {
    var oldValue = _wrapPrimitive<Value>(_getRaw(operands.first!));

    operands.first!.value = _wrapPrimitive(_getRaw(operands.first!) + 1);

    return oldValue.createHandle();
  }

  static Handle? dot(Iterable<Handle?> operands) {
    return operands.first!.value
        .instanceMember(operands.last!.value.toString());
  }

  static Handle? colon(Iterable<Handle?> operands) {
    return operands.first!.value.staticMember(operands.last!.value.toString());
  }

  // Handles uses of '[]' for declaring array types and for accessing
  //  values by key/index in collections.
  static Handle? subscript(Iterable<Handle?> operands) {
    // "Type[]" is an array of values of type 'Type'.
    if (operands.first!.value is ValueType) {
      return ArrayType(operands.first!.value as ValueType).createHandle();
    }

    // "something[n]" is an access to the nth item in the 'something'.
    return operands.first!.value.at(operands.last!.value);
  }

  static Handle? Function(Iterable<Handle?>)? getOperation(Token token) {
    var callPattern = GroupPattern('call', '');
    var subscriptPattern = GroupPattern('[', ']');

    if (callPattern.notMatch(token) && subscriptPattern.notMatch(token)) {
      return ShuntingYard.operators[token.toString()]!.operation;
    }

    if (subscriptPattern.hasMatch(token)) {
      var keyExpression = Parse.expression(token.allTokens());

      return (operands) {
        var key = keyExpression.evaluate()!;
        return operands.first!.value.at(key.value);
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

    // TODO: Allow operators to throw exceptions.
    return (a) => _createCall(arguments)(a)!.returned;
  }

  static SideEffect? Function(Iterable<Handle?>) _createCall(
      List<Expression> args) {
    return (operands) {
      var value = operands.first!.value;

      // We only get one operand, and that's the thing being called.
      if (!(value is Callable)) {
        throw Exception('Cannot call non-function "$value"!');
      }

      var functionValue = value;
      var parameters = functionValue.parameters!;

      var argumentsArray = <Handle?>[];
      for (var expression in args) {
        argumentsArray.add(expression.evaluate());
      }

      if (argumentsArray.length != parameters.length) {
        throw Exception(
            'Incorrect number of arguments in call to function "$value"! '
            '(Expected ${parameters.length}, got ${argumentsArray.length}.)');
      }

      // Map the arguments to their names.
      var mappedArguments = <String?, Handle?>{};
      var parameterNames = parameters.keys.toList();

      for (var i = 0; i < argumentsArray.length; ++i) {
        mappedArguments[parameterNames[i]] = argumentsArray[i];
      }

      return functionValue.call(mappedArguments);
    };
  }

  static Handle not(Iterable<Handle?> operands) {
    return _wrapPrimitive(_getRaw<int>(operands.first!) != 0 ? 0 : 1);
  }

  static Handle bitnot(Iterable<Handle?> operands) {
    return _wrapPrimitive(~_getRaw<int>(operands.first!));
  }

  static Handle inlineDirection(Iterable<Handle?> operands) {
    return Handle.reference(operands.first);
  }

  static Handle unaryMinus(Iterable<Handle?> operands) {
    return _wrapPrimitive(-_getRaw(operands.first!));
  }

  static Handle referenceTo(Iterable<Handle?> operands) {
    return ReferenceType.to(operands.first!.value as ValueType).createHandle();
  }

  static Handle multiply(Iterable<Handle?> operands) {
    return _wrapPrimitive(_getRaw(operands.first!) * _getRaw(operands.last!));
  }

  static Handle divide(Iterable<Handle?> operands) {
    return _wrapPrimitive(_getRaw(operands.first!) / _getRaw(operands.last!));
  }

  static Handle modulus(Iterable<Handle?> operands) {
    return _wrapPrimitive(_getRaw(operands.first!) % _getRaw(operands.last!));
  }

  static Handle add(Iterable<Handle?> operands) {
    return _wrapPrimitive(_getRaw(operands.first!) + _getRaw(operands.last!));
  }

  static Handle subtract(Iterable<Handle?> operands) {
    return _wrapPrimitive(_getRaw(operands.first!) - _getRaw(operands.last!));
  }

  static Handle lessThan(Iterable<Handle?> operands) {
    return _wrapPrimitive(operands.first!.lessThan(operands.last!));
  }

  static Handle lessThanOrEqual(Iterable<Handle?> operands) {
    return _wrapPrimitive(operands.first!.lessThanOrEqualTo(operands.last!));
  }

  static Handle greaterThan(Iterable<Handle?> operands) {
    return _wrapPrimitive(operands.first!.greaterThan(operands.last!));
  }

  static Handle greaterThanEqual(Iterable<Handle?> operands) {
    return _wrapPrimitive(operands.first!.greaterThanOrEqualTo(operands.last!));
  }

  static Handle cast(Iterable<Handle?> operands) {
    return operands.first!.convertHandleTo(operands.last!.value as ValueType);
  }

  static Handle equal(Iterable<Handle?> operands) {
    return _wrapPrimitive(operands.first!.equals(operands.last!));
  }

  static Handle notEqual(Iterable<Handle?> operands) {
    return _wrapPrimitive(operands.first!.notEquals(operands.last!));
  }

  static Handle bitand(Iterable<Handle?> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first!) & _getRaw<int>(operands.last!));
  }

  static Handle xor(Iterable<Handle?> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first!) ^ _getRaw<int>(operands.last!));
  }

  static Handle bitor(Iterable<Handle?> operands) {
    return _wrapPrimitive(
        _getRaw<int>(operands.first!) | _getRaw<int>(operands.last!));
  }

  static Handle and(Iterable<Handle?> operands) {
    return _wrapPrimitive(
        _getRaw<bool>(operands.first!) && _getRaw<bool>(operands.last!));
  }

  static Handle or(Iterable<Handle?> operands) {
    return _wrapPrimitive(
        _getRaw<bool>(operands.first!) || _getRaw<bool>(operands.last!));
  }

  static Handle assign(Iterable<Handle?> operands) {
    operands.first!.value = operands.last!.value;
    return NullType.nullHandle();
  }

  static Handle addAssign(Iterable<Handle?> operands) {
    operands.first!.value = add(operands).value;
    return _wrapPrimitive(operands.first);
  }

  static Handle subtractAssign(Iterable<Handle?> operands) {
    operands.first!.value = subtract(operands).value;
    return _wrapPrimitive(operands.first);
  }

  static Handle multiplyAssign(Iterable<Handle?> operands) {
    operands.first!.value = multiply(operands).value;
    return _wrapPrimitive(operands.first);
  }

  static Handle divideAssign(Iterable<Handle?> operands) {
    operands.first!.value = divide(operands).value;
    return _wrapPrimitive(operands.first);
  }
}
