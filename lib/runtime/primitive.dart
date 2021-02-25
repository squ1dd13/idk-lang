import 'concrete.dart';
import 'exception.dart';
import 'function.dart';
import 'handle.dart';
import 'scope.dart';
import 'statements.dart';
import 'type.dart';
import 'value.dart';

enum Primitive { Int, String, Bool }

class PrimitiveType extends ValueType {
  final Primitive _type;

  static PrimitiveType get integer => PrimitiveType(Primitive.Int);

  static PrimitiveType get string => PrimitiveType(Primitive.String);

  static PrimitiveType get boolean => PrimitiveType(Primitive.Bool);

  PrimitiveType(this._type);

  @override
  String toString() {
    return _type == Primitive.Int
        ? 'int'
        : (_type == Primitive.String ? 'String' : 'bool');
  }

  @override
  bool equals(Value other) {
    return other is PrimitiveType && _type == other._type;
  }
}

abstract class PrimitiveValue extends Value {
  dynamic get rawValue;

  @override
  bool equals(Value other) {
    return (other is PrimitiveValue) && rawValue == other.rawValue;
  }

  @override
  bool greaterThan(Value other) {
    return (other is PrimitiveValue) && rawValue > other.rawValue;
  }

  @override
  bool lessThan(Value other) {
    return (other is PrimitiveValue) && rawValue < other.rawValue;
  }
}

class IntegerValue extends PrimitiveValue {
  int value;

  IntegerValue.raw(this.value) {
    type = PrimitiveType(Primitive.Int);
  }

  IntegerValue(String string) : value = int.parse(string) {
    type = PrimitiveType(Primitive.Int);
  }

  @override
  String toString() => value.toString();

  @override
  Value copyValue() {
    return IntegerValue.raw(value);
  }

  @override
  int get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegerValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  Handle instanceMember(String name) {
    if (name == 'getPrint') {
      return Scope.current().get('print');
    }

    throw RuntimeError('Unable to find "$name" on type "$type".');
  }
}

class StringValue extends PrimitiveValue {
  String value;

  StringValue(this.value) {
    type = PrimitiveType(Primitive.String);
  }

  @override
  String toString() => value;

  @override
  Value copyValue() {
    return StringValue(value);
  }

  @override
  String get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StringValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  Handle instanceMember(String name) {
    if (name == 'length') {
      var func = FunctionValue('length', PrimitiveType.integer, <Statement>[
        DartDynamicStatement(() {
          return SideEffect.returns(
              IntegerValue.raw(value.length).createHandle());
        }, false)
      ])
        ..applyType();

      return func.createHandle();
    }

    throw RuntimeError('Unable to find "$name" on type "$type".');
  }

  @override
  Handle at(Value key) {
    return StringValue(value[(key as IntegerValue).value]).createHandle();
  }
}

class BooleanValue extends PrimitiveValue {
  bool value;

  @override
  bool get rawValue => value;

  BooleanValue(this.value) {
    type = PrimitiveType.boolean;
  }

  @override
  Value copyValue() {
    return BooleanValue(value);
  }

  @override
  bool equals(Value other) {
    return other is BooleanValue && other.value == value;
  }
}
