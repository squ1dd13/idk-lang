import 'Exceptions.dart';
import 'Types.dart';

/// Some component of the language.
abstract class Concept {}

/// Any concrete value.
abstract class Value implements Concept, Evaluable {
  @override
  Value get() => this;
}

/// Something which can resolve to a value.
abstract class Evaluable implements Concept {
  Value get();

  Evaluable copy();
}

/// Something with a type.
abstract class TypedValue implements Evaluable {
  Value _value;
  ValueType type;
}

class Variable extends TypedValue implements Evaluable {
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

  void set(TypedValue source) {
    var conversion = source.type.conversionTo(type);

    // Any conversions should have taken place before setting the value,
    //  so by now, newValue's type should be the same as _value's.
    if (conversion != TypeConversion.NoConversion) {
      throw RuntimeError('Attempted to replace value of type "${type}" with'
          ' one of type "${source.type}"!');
    }

    // Ensure the types are compatible.
    // if (!source.type.canConvertTo(type)) {
    //   throw RuntimeError(
    //       'Cannot assign value of type ${source.type} to variable of type $type!');
    // }

    _value = source.get();
  }

  @override
  Evaluable copy() {
    return Variable(type, _value);
  }
}

class Constant extends TypedValue {
  @override
  Value get() => _value;

  @override
  Evaluable copy() {
    // TODO: implement copy
    throw UnimplementedError();
  }
}
