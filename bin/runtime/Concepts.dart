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
    var conversion = source.type.conversionTo(type);

    // Any conversions should have taken place before setting the value,
    //  so by now, newValue's type should be the same as _value's.
    if (conversion != TypeConversion.NoConversion) {
      throw RuntimeError('Attempted to replace value of type "${type}" with'
          ' one of type "${source.type}"!');
    }

    _value = source.get();
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
