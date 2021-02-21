import 'exception.dart';
import 'type.dart';
import 'value.dart';

/// Something which owns a value. 99% of work done with values should be
/// through a [Handle].
abstract class Handle {
  Value get value;

  set value(Value newValue);

  /// Only exists to allow extending.
  Handle();

  /// Returns a handle appropriate for the value's type.
  factory Handle.create(Value value) {
    // TODO: If the value's type is constant, return a Constant handle.
    return Variable(value);
  }

  /// Returns a reference to [handle].
  factory Handle.reference(Handle handle) {
    return Reference(handle);
  }

  // Note that we specify "handle" and "value" in many of the identifiers here.
  // This is to make it clear what the user is working with - handles or values.

  /// The type of the underlying value of this handle.
  ValueType get valueType;

  /// The type of this handle itself. This should be the same as the [valueType]
  /// in most cases, although [Reference]s will return their reference type.
  ValueType get handleType;

  /// Returns a copy of this handle. This method may or may not
  /// also copy the underlying value.
  Handle copyHandle();

  /// Returns a [Handle] created from converting this handle's value to
  /// [endType]. The handle returned may be the same as the original.
  Handle convertValueTo(ValueType endType);

  /// Returns a [Handle] created from converting this handle such that the
  /// new [Handle]'s [handleType] is equal to [endType].
  Handle convertHandleTo(ValueType endType);

  // We define basic comparisons to pass through to the underlying values.

  bool equals(Handle other) => value.equals(other.value);

  bool notEquals(Handle other) => !equals(other);

  bool greaterThan(Handle other) => value.greaterThan(other.value);

  bool lessThan(Handle other) => value.lessThan(other.value);

  bool greaterThanOrEqualTo(Handle other) =>
      greaterThan(other) || equals(other);

  bool lessThanOrEqualTo(Handle other) => lessThan(other) || equals(other);

  @override
  bool operator ==(Object other) {
    throw Exception("Don't compare handles with ==.");
  }

  @override
  String toString() => value.toString();
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
