import 'Exceptions.dart';
import 'Types.dart';

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
}

class Constant extends Value {
  @override
  Value get() => this;

  @override
  Value copy() {
    throw Exception('go away');
  }
}
