import 'package:language/runtime/standard/interop.dart';

import 'exception.dart';
import 'handle.dart';
import 'object.dart';
import 'type.dart';

/// Something with a type. Avoid using this directly; prefer [Handle]s,
/// especially when passing values around.
abstract class Value {
  ValueType? type;

  Value copyValue();

  Value mustConvertTo(ValueType? endType) {
    var sourceType = type!;

    if (sourceType.equals(endType)) {
      return this;
    }

    if (endType!.equals(ReferenceType.to(type))) {
      return Reference(createHandle()).value;
    }

    if (endType.equals(AnyType.any) && !(type is ReferenceType)) {
      return this;
    }

    if (sourceType is ClassType && endType is ClassType) {
      // The conversion is legal if the source type is a subclass of the
      //  end type.
      if (sourceType.inheritsFrom(endType)) {
        return this;
      }
    }

    if (sourceType is NullType) {
      return endType.nullValue();
    }

    if (endType is DartType) {
      return DartObject.from(createHandle());
    }

    throw RuntimeError('Cannot convert from '
        'type "${sourceType}" to type "$endType".');
  }

  // TODO: Remove this and generalise.
  Handle? at(Value key) {
    throw RuntimeError('$type does not support "[]".');
  }

  /// Helper method to create a [Handle] for this value.
  Handle createHandle() => Handle.create(this);

  Handle createConstant() => Handle.constant(this);

  bool equals(Value? other);

  bool notEquals(Value? other) => !equals(other);

  bool greaterThan(Value other);

  bool lessThan(Value other);

  bool greaterThanOrEqualTo(Value other) => greaterThan(other) || equals(other);

  bool lessThanOrEqualTo(Value other) => lessThan(other) || equals(other);

  @override
  bool operator ==(Object other) {
    throw Exception("Don't compare Values with ==.");
  }

  Handle? instanceMember(String name) {
    throw RuntimeError('Cannot use "." with "$type".');
  }

  Handle? staticMember(String name) {
    throw RuntimeError('Cannot use ":" with "$type".');
  }
}

class NulledValue extends Value {
  NulledValue(ValueType type) {
    super.type = type;
  }

  @override
  Value copyValue() {
    return this;
  }

  @override
  bool equals(Value? other) {
    return other is NulledValue && type!.equals(other.type);
  }

  @override
  bool greaterThan(Value other) {
    // TODO: implement greaterThan
    throw UnimplementedError();
  }

  @override
  bool lessThan(Value other) {
    // TODO: implement lessThan
    throw UnimplementedError();
  }

  @override
  String toString() {
    return 'null';
  }
}
