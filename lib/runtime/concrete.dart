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
  Value thrownValue;

  SideEffect.nothing();

  SideEffect.breaks({String name = ''}) {
    breakName = name;
  }

  SideEffect.continues({String name = ''}) {
    continueName = name;
  }

  SideEffect.throws(this.thrownValue);

  SideEffect.returns(this.returnedValue);

  bool continuesLoopName(String name) {
    // If the name is empty, we match any loop (the first loop that handles
    //  the effect). If the name is null, the effect is not present.
    return continueName != null &&
        (continueName.isEmpty || continueName == name);
  }

  bool breaksLoopName(String name) {
    return breakName != null && (breakName.isEmpty || breakName == name);
  }

  bool get isLoopInterrupt => breakName != null || continueName != null;

  bool get isInterrupt =>
      breakName != null ||
      continueName != null ||
      returnedValue != null ||
      thrownValue != null;
}

/// A single unit of code which affects the program without
/// producing a value when finished.
class Statement {
  /// Doesn't return a value.
  final Expression _fullExpression;

  Statement(this._fullExpression);

  SideEffect execute() {
    _fullExpression.evaluate();
    return SideEffect.nothing();
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

  @override
  Value at(Value key) {
    return _value.at(key);
  }
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

  @override
  Value at(Value key) {
    return _value.at(key);
  }
}

/// 'any' but for elements from collection literals. We need
/// this class because we don't know the collection type
/// immediately, so we need a type we can convert to the real
/// element type as soon as we find it out.
class ElementType extends AnyType {
  @override
  TypeConversion conversionTo(ValueType to) {
    if (to is ReferenceType) {
      return TypeConversion.None;
    }

    return TypeConversion.NoConversion;
  }

  @override
  Value copy() {
    return ElementType();
  }

  @override
  String toString() {
    return 'element';
  }
}

class ArrayValue extends Value {
  final List<Value> elements;

  ArrayValue(ArrayType arrayType, this.elements) {
    type = arrayType;
  }

  @override
  Value copy() {
    // Copy element-by-element.
    var copiedElements = elements.map((e) => e.copy()).toList(growable: false);

    return ArrayValue(type.copy() as ArrayType, copiedElements);
  }

  @override
  bool equals(Evaluable other) {
    var otherValue = other.get();

    if (otherValue.type.conversionTo(type) != TypeConversion.NoConversion) {
      return false;
    }

    var otherArray = otherValue as ArrayValue;
    if (elements.length != otherArray.elements.length) {
      return false;
    }

    for (var i = 0; i < elements.length; ++i) {
      if (elements[i].notEquals(otherArray.elements[i])) {
        return false;
      }
    }

    return true;
  }

  @override
  bool notEquals(Evaluable other) {
    var otherValue = other.get();

    if (otherValue.type.conversionTo(type) != TypeConversion.NoConversion) {
      return true;
    }

    var otherArray = otherValue as ArrayValue;
    if (elements.length != otherArray.elements.length) {
      return true;
    }

    for (var i = 0; i < elements.length; ++i) {
      if (elements[i].notEquals(otherArray.elements[i])) {
        return true;
      }
    }

    return false;
  }

  // Not sure what to do with these yet.
  @override
  bool greaterThan(Evaluable other) {
    throw UnimplementedError();
  }

  @override
  bool lessThan(Evaluable other) {
    throw UnimplementedError();
  }

  @override
  Value at(Value key) {
    return elements[(key as IntegerValue).rawValue];
  }
}
