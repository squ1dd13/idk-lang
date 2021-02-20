import 'exception.dart';
import 'type.dart';

/// Something which can *resolve* to a value, but which may not itself be
/// a value.
abstract class Evaluable {
  Value get();

  bool equals(Evaluable other);

  bool notEquals(Evaluable other) => !equals(other);

  bool greaterThan(Evaluable other);

  bool lessThan(Evaluable other);

  bool greaterThanOrEqualTo(Evaluable other) =>
      greaterThan(other) || equals(other);

  bool lessThanOrEqualTo(Evaluable other) => lessThan(other) || equals(other);

  @override
  bool operator ==(Object other) {
    throw Exception("Don't compare Evaluables with ==.");
  }
}

/// Something with a type.
abstract class Value extends Evaluable {
  ValueType type;

  @override
  Value get() => this;

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

    return sourceType.convertObjectTo(copyValue(), endType);
  }

  Value at(Value key) {
    throw RuntimeError('$type does not support "[]".');
  }
}
