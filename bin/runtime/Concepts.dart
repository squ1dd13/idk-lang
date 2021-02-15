import 'Concrete.dart';
import 'Util.dart';

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

abstract class ValueType extends Value {
  // bool canTakeFrom(ValueType other);
  bool canConvertTo(ValueType other);
}

/// A class type. Equality is determined by name.
class ClassType extends ValueType {
  final String name;

  ClassType(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassType &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  bool canConvertTo(ValueType other) {
    return this == other;
  }

  @override
  Evaluable copy() {
    return ClassType(name);
  }
}

/// Something with a type.
abstract class TypedValue implements Evaluable {
  Value _value;
  ValueType type;
}

class Variable extends TypedValue implements Evaluable {
  Variable(ValueType theType, Value theValue) {
    if (theType is ReferenceType) {
      throw Exception('Variables may not be of reference type!');
    }

    _value = theValue;
    type = theType;
  }

  @override
  Value get() {
    return _value;
  }

  void set(TypedValue source) {
    // Ensure the types are compatible.
    if (!source.type.canConvertTo(type)) {
      throw Exception(
          'Cannot assign value of type ${source.type} to variable of type $type!');
    }

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
