import 'exception.dart';
import 'type.dart';

/// Something which can *resolve* to a value, but which may not itself be
/// a value.
abstract class Evaluable {
  Value get();
}

/// Something with a type.
abstract class Value implements Evaluable {
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

