import 'abstract.dart';
import 'exception.dart';
import 'expression.dart';
import 'type.dart';

abstract class PrimitiveValue extends Value {
  dynamic get rawValue;

  @override
  bool equals(Evaluable other) {
    return (other is PrimitiveValue) && rawValue == other.rawValue;
  }

  @override
  bool greaterThan(Evaluable other) {
    return (other is PrimitiveValue) && rawValue > other.rawValue;
  }

  @override
  bool lessThan(Evaluable other) {
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
  Value get() => this;

  @override
  Value copy() {
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
  Value get() => this;

  @override
  Value copy() {
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

class SideEffect {
  String breakName;
  String continueName;
  Value returnedValue;

  // TODO: 'throws' flag (and exception value).

  bool get interrupts {
    return breakName != null || continueName != null || returnedValue != null;
  }
}

/// A single unit of code which affects the program without
/// producing a value when finished.
class Statement {
  /// Doesn't return a value.
  final Expression _fullExpression;

  Statement(this._fullExpression);

  SideEffect execute() {
    _fullExpression.evaluate();
    return SideEffect();
  }
}

class SideEffectStatement extends Statement {
  final SideEffect Function() _action;

  SideEffectStatement(this._action) : super(null);

  @override
  SideEffect execute() {
    return _action();
  }
}

class Variable extends Value {
  Value _value;

  Variable(ValueType theType, Value theValue) {
    if (theType is ReferenceType) {
      throw RuntimeError('Variables may not be of reference type!');
    }

    _value = theValue;
    type = theType;
  }

  @override
  Value get() {
    return _value;
  }

  void set(Value source) {
    // Keep things type-safe by ensuring that the value is of the correct type.
    _value = source.mustConvertTo(type);
  }

  @override
  Value copy() {
    return Variable(type.copy(), _value.copy());
  }

  @override
  bool equals(Evaluable other) => _value.equals(other);

  @override
  bool greaterThan(Evaluable other) => _value.greaterThan(other);

  @override
  bool lessThan(Evaluable other) => _value.lessThan(other);
}

/// Essentially a pointer, but with added safety and with custom
/// syntax to increase clarity. Behaves like a variable when used
/// like one (with normal syntax). Implements [Variable] so it can
/// provide a transparent but custom interface.
class Reference extends Value implements Variable {
  @override
  Value _value;

  @override
  ValueType type;

  Reference(Value value) {
    _value = value;
    type = ReferenceType.forReferenceTo(value.type);
  }

  @override
  Value get() {
    return _value.get();
  }

  @override
  void set(Value source) {
    if (_value is Variable) {
      // Let _referenced handle the type checking.
      (_value as Variable).set(source);
    } else {
      throw RuntimeError(
          'Cannot set value through reference to non-variable value.');
    }
  }

  void redirect(Value source) {
    if (source.type.conversionTo(type) != TypeConversion.None) {
      throw RuntimeError('Cannot redirect reference of type $type '
          'to value of type ${source.type}!');
    }

    _value = source;
  }

  @override
  Value copy() {
    // Note that we don't copy _value.
    return Reference(_value);
  }

  @override
  bool equals(Evaluable other) => _value.equals(other);

  @override
  bool greaterThan(Evaluable other) => _value.greaterThan(other);

  @override
  bool lessThan(Evaluable other) => _value.lessThan(other);
}
