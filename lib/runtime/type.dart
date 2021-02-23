import 'handle.dart';
import 'primitive.dart';
import 'value.dart';

abstract class ValueType extends Value {
  @override
  ValueType get type => TypeOfType.shared;

  @override
  Value copyValue() => this;

  @override
  bool greaterThan(Value other) {
    return hashCode > other.hashCode;
  }

  @override
  bool lessThan(Value other) {
    return hashCode < other.hashCode;
  }
}

/// The type of value types.
class TypeOfType extends ValueType {
  static TypeOfType shared = TypeOfType();

  @override
  bool equals(Value other) {
    return other is TypeOfType;
  }
}

class AnyType extends ValueType {
  static AnyType any = AnyType();

  @override
  String toString() {
    return 'Any';
  }

  @override
  bool equals(Value other) {
    return other is AnyType;
  }
}

class NullType extends ValueType {
  @override
  Value copyValue() {
    return NullType();
  }

  /// [NullType] is likely to be printed in errors, but 'proc'
  /// doesn't make sense in all errors (e.g. you can't return
  /// 'proc' from a function), so we can specify a different
  /// name to use.
  String _name;

  NullType({String name = 'proc'}) {
    _name = name;
  }

  static Value nullValue() {
    var integer = IntegerValue.raw(0);
    integer.type = NullType(name: 'null');

    return integer;
  }

  static Handle nullHandle() {
    return nullValue().createHandle();
  }

  @override
  String toString() {
    return _name;
  }

  @override
  bool equals(Value other) {
    return other is NullType;
  }
}

class ReferenceType extends ValueType {
  final ValueType referencedType;

  ReferenceType.to(this.referencedType);

  @override
  Value copyValue() {
    return ReferenceType.to(referencedType.copyValue());
  }

  @override
  String toString() {
    return '@($referencedType)';
  }

  @override
  bool equals(Value other) {
    return other is ReferenceType &&
        referencedType.equals(other.referencedType);
  }
}

/// 'Any' but for elements from collection literals. We need
/// this class because we don't know the collection type
/// immediately, so we need a type we can convert to the real
/// element type as soon as we find it out.
class ElementType extends AnyType {
  @override
  Value copyValue() {
    return ElementType();
  }

  @override
  String toString() {
    return 'element';
  }

  @override
  bool equals(Value other) {
    return other is ElementType;
  }
}

class ArrayType extends ValueType {
  final ValueType elementType;

  ArrayType(this.elementType);

  @override
  Value copyValue() {
    return ArrayType(elementType.copyValue());
  }

  @override
  String toString() {
    return '$elementType[]';
  }

  @override
  bool equals(Value other) {
    if (!(other is ArrayType)) {
      return false;
    }

    var array = other as ArrayType;
    return elementType.equals(array.elementType);
  }
}
