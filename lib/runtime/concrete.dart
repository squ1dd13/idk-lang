
import 'abstract.dart';
import 'exception.dart';
import 'expression.dart';
import 'type.dart';

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
  Value get() => this;

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
  Value get() => this;

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

class SideEffect {
  String breakName;
  String continueName;
  Handle returned;
  Handle thrown;

  SideEffect.nothing();

  SideEffect.breaks({String name = ''}) {
    breakName = name;
  }

  SideEffect.continues({String name = ''}) {
    continueName = name;
  }

  SideEffect.throws(this.thrown);

  SideEffect.returns(this.returned);

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
      returned != null ||
      thrown != null;
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

class Variable extends Handle {
  Value _value;

  Variable(this._value);

  @override
  Value get value => _value;

  @override
  set value(Value newValue) {
    var conversion = newValue.type.conversionTo(valueType);

    if (!ValueType.isConversionImplicit(conversion)) {
      throw RuntimeError('Cannot set value of "${valueType}" variable to '
          '"${newValue.type}"');
    }

    _value = newValue.mustConvertTo(valueType);
  }

  @override
  Handle convertValueTo(ValueType endType) {
    return Handle.create(value.mustConvertTo(endType));
  }

  @override
  Handle convertHandleTo(ValueType endType) => convertValueTo(endType);

  @override
  Handle copyHandle() {
    // Variables copy values around with them - two Variables should never share
    //  a Value object.
    return Handle.create(value.copyValue());
  }

  @override
  ValueType get valueType => _value.type;

  @override
  ValueType get handleType => valueType;
}

/// Almost exactly the same as [Variable], except that the value may not be
/// set more than once.
class Constant extends Variable {
  Constant(Value value) : super(value);

  @override
  set value(Value newValue) {
    throw RuntimeError('Cannot set value of constant.');
  }
}

class Reference extends Handle {
  // Variable, Constant etc.
  Handle _valueHandle;

  Reference(this._valueHandle);

  @override
  Value get value => _valueHandle.value;

  @override
  set value(Value newValue) {
    _valueHandle.value = newValue.mustConvertTo(value.type);
  }

  @override
  Handle copyHandle() {
    // We're copying this handle, so the result is a new reference to the
    //  same base handle.
    return Handle.reference(_valueHandle);
  }

  @override
  ValueType get valueType => _valueHandle.valueType;

  @override
  ValueType get handleType => ReferenceType.to(valueType);

  void redirect(Handle newTarget) {
    var conversion = newTarget.valueType.conversionTo(valueType);

    if (!ValueType.isConversionImplicit(conversion)) {
      throw RuntimeError('Cannot change target from "${valueType}" to '
          '"${newTarget.valueType}"');
    }

    _valueHandle = newTarget;
  }

  @override
  Handle convertValueTo(ValueType endType) {
    var conversion = valueType.conversionTo(endType);

    if (conversion == TypeConversion.None) {
      // We can just return this reference, because there is no conversion
      //  involved.
      return this;
    }

    // Return a reference to the converted handle, or throw an exception if
    //  we couldn't convert (this happens in mustConvertTo).
    return Handle.reference(_valueHandle.convertValueTo(endType));
  }

  @override
  Handle convertHandleTo(ValueType endType) {
    if (!(endType is ReferenceType)) {
      // The caller wants a non-reference handle, so we need to convert the
      //  underlying handle.
      return _valueHandle.convertHandleTo(endType);
    }

    var conversion = handleType.conversionTo(endType);

    if (conversion == TypeConversion.None) {
      return this;
    }

    var newValueType = (endType as ReferenceType).referencedType;
    return Handle.reference(_valueHandle.convertValueTo(newValueType));
  }
}

class InitializerListType extends ValueType {
  @override
  TypeConversion conversionTo(ValueType to) {
    return TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    return (object as InitializerList)
        .convertToArray((endType as ArrayType).elementType);
  }

  @override
  Value copyValue() {
    return this;
  }
}

class InitializerList extends Value {
  final contents = <Handle>[];

  @override
  Value copyValue() {
    throw RuntimeError('Cannot copy initialiser lists.');
  }

  @override
  bool equals(Value other) {
    throw RuntimeError('Cannot compare initialiser lists.');
  }

  @override
  bool greaterThan(Value other) {
    throw RuntimeError('Cannot compare initialiser lists.');
  }

  @override
  bool lessThan(Value other) {
    throw RuntimeError('Cannot compare initialiser lists.');
  }

  Value convertToArray(ValueType elementType) {
    var values = contents.map((e) => e.convertHandleTo(elementType)).toList();
    return ArrayValue(ArrayType(elementType), values);
  }

  @override
  Value mustConvertTo(ValueType endType) {
    if (!(endType is ArrayType)) {
      throw RuntimeError('Initialiser lists may only be converted to arrays.');
    }

    return convertToArray((endType as ArrayType).elementType);
  }
}

class ArrayValue extends Value {
  List<Handle> elements;

  ArrayValue(ArrayType arrayType, List<Handle> handles) {
    type = arrayType;

    elements = List<Handle>.filled(handles.length, null);

    for (var i = 0; i < handles.length; ++i) {
      elements[i] = handles[i].copyHandle();
    }
  }

  @override
  Value copyValue() {
    // The element handles will be copied by the constructor.
    return ArrayValue(type.copyValue() as ArrayType, elements);
  }

  @override
  bool equals(Value other) {
    if (other.type.conversionTo(type) != TypeConversion.NoConversion) {
      return false;
    }

    var otherArray = other as ArrayValue;
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
  bool notEquals(Value other) {
    if (other.type.conversionTo(type) != TypeConversion.NoConversion) {
      return true;
    }

    var otherArray = other as ArrayValue;
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
  bool greaterThan(Value other) {
    throw UnimplementedError();
  }

  @override
  bool lessThan(Value other) {
    throw UnimplementedError();
  }

  @override
  Handle at(Value key) {
    return elements[(key as IntegerValue).rawValue];
  }
}
