import 'concrete.dart';
import 'exception.dart';
import 'type.dart';

/// Something with a type.
abstract class Value {
  ValueType type;

  Value copyValue();

  Value mustConvertTo(ValueType endType) {
    var sourceType = type;

    if (sourceType.equals(endType)) {
      return this;
    }

    var conversionType = sourceType.conversionTo(endType);
    if (!ValueType.isConversionImplicit(conversionType)) {
      throw RuntimeError('Cannot implicitly convert from '
          'type "${sourceType}" to type "$endType".');
    }

    return sourceType.convertObjectTo(this, endType);
  }

  Handle at(Value key) {
    throw RuntimeError('$type does not support "[]".');
  }

  bool equals(Value other);

  bool notEquals(Value other) => !equals(other);

  bool greaterThan(Value other);

  bool lessThan(Value other);

  bool greaterThanOrEqualTo(Value other) => greaterThan(other) || equals(other);

  bool lessThanOrEqualTo(Value other) => lessThan(other) || equals(other);

  @override
  bool operator ==(Object other) {
    throw Exception("Don't compare Evaluables with ==.");
  }
}

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
