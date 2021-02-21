import 'exception.dart';
import 'handle.dart';
import 'type.dart';

/// Something with a type. Avoid using this directly; prefer [Handle]s,
/// especially when passing values around.
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

  // TODO: Remove this and generalise.
  Handle at(Value key) {
    throw RuntimeError('$type does not support "[]".');
  }

  /// Helper method to create a [Handle] for this value.
  Handle createHandle() => Handle.create(this);

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
