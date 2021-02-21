import 'exception.dart';
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrimitiveType &&
          runtimeType == other.runtimeType &&
          _type == other._type;

  @override
  int get hashCode => _type.hashCode;

  @override
  Value copyValue() {
    return PrimitiveType(_type);
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    if (this == to || to is AnyType) {
      return TypeConversion.NoConversion;
    }

    return TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }

  @override
  Value convertObjectFrom(Value object, ValueType startType) {
    if (this == startType) {
      return object;
    }

    if (_type == Primitive.Int) {
      throw RuntimeError("Can't use cOF for integers.");
    }

    // Everything has toString().
    return StringValue(object.toString());
  }

  @override
  String toString() {
    return _type == Primitive.Int
        ? 'int'
        : (_type == Primitive.String ? 'string' : 'bool');
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
