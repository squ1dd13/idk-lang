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
    throw Exception('Don\'t compare Evaluables with ==.');
  }
}

/// Something with a type.
abstract class Value extends Evaluable {
  ValueType type;

  @override
  Value get() => this;

  Value copy();

  Value mustConvertTo(ValueType endType) {
    var sourceType = type;

    var conversionType = sourceType.conversionTo(endType);
    if (!ValueType.isConversionImplicit(conversionType)) {
      throw RuntimeError('Cannot implicitly convert from '
          'type "${sourceType}" to type "$endType".');
    }

    return sourceType.convertObjectTo(copy(), endType);
  }
}
