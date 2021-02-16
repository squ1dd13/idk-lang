import 'Concepts.dart';
import 'Concrete.dart';
import 'Exceptions.dart';

/// Describes how one type may be converted to another.
enum TypeConversion {
  /// The conversion is always illegal.
  None,

  /// May be automatic (without a cast). A cast is also allowed.
  Implicit,

  /// Not automatic, so a cast must always be used.
  Explicit,

  /// No conversion required (types are the same).
  NoConversion
}

abstract class ValueType extends Value {
  // bool canTakeFrom(ValueType other);
  bool canConvertTo(ValueType other);

  /// Returns a [TypeConversion] value indicating the style of conversion
  /// that may take place between this type and the type [to].
  TypeConversion conversionTo(ValueType to);

  void assertConvertibleTo(ValueType endType) {
    if (conversionTo(endType) == TypeConversion.None) {
      throw RuntimeError('Cannot convert from "$this" to "$endType".');
    }
  }

  TypedValue convertObjectTo(TypedValue object, ValueType endType);

  TypedValue convertObjectFrom(TypedValue object, ValueType startType) {
    throw UnimplementedError('cOF');
  }
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

  @override
  TypeConversion conversionTo(ValueType to) {
    // The only 'conversion' that may take place is from this type to
    //  the same type, or to 'any'.
    if (this == to || to is AnyType) {
      return TypeConversion.NoConversion;
    }

    // TODO: Allow classes to define casts to arbitrary types.

    return TypeConversion.None;
  }

  @override
  TypedValue convertObjectTo(TypedValue object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }
}

class AnyType extends ValueType {
  @override
  bool canConvertTo(ValueType other) {
    return true;
  }

  @override
  Evaluable copy() {
    return AnyType();
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    // You cannot convert a non-reference value to a reference value.
    // That wouldn't make sense.
    if (to is ReferenceType) {
      return TypeConversion.None;
    }

    // The 'any' type should be casted for clarity of types.
    return TypeConversion.Explicit;
  }

  @override
  TypedValue convertObjectTo(TypedValue object, ValueType endType) {
    assertConvertibleTo(endType);
    return endType.convertObjectFrom(object, this);
  }

  @override
  String toString() {
    return 'any';
  }
}

class NoType extends ValueType {
  @override
  bool canConvertTo(ValueType other) {
    return false;
  }

  @override
  Evaluable copy() {
    return NoType();
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    return to is NoType ? TypeConversion.NoConversion : TypeConversion.None;
  }

  @override
  TypedValue convertObjectTo(TypedValue object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }

  @override
  String toString() {
    return 'proc';
  }
}

class PrimitiveType extends ValueType {
  final Primitive _type;

  PrimitiveType(this._type);

  @override
  bool canConvertTo(ValueType other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrimitiveType &&
          runtimeType == other.runtimeType &&
          _type == other._type;

  @override
  int get hashCode => _type.hashCode;

  @override
  Evaluable copy() {
    return PrimitiveType(_type);
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    // TODO: Explicit casts from string to int and from int to string.

    if (this == to || to is AnyType) {
      return TypeConversion.NoConversion;
    }

    return TypeConversion.None;
  }

  @override
  TypedValue convertObjectTo(TypedValue object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }

  @override
  String toString() {
    return _type == Primitive.Int ? 'int' : 'string';
  }
}

class ReferenceType extends ValueType {
  final ValueType referencedType;

  ReferenceType.forReferenceTo(this.referencedType);

  @override
  bool canConvertTo(ValueType other) {
    return referencedType.canConvertTo(other);
  }

  @override
  Evaluable copy() {
    return ReferenceType.forReferenceTo(referencedType);
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    if (!(to is ReferenceType)) {
      // Implicit or non-conversions to the referenced type are fine.
      var dereferenceConversion = referencedType.conversionTo(to);
      if (dereferenceConversion == TypeConversion.NoConversion ||
          dereferenceConversion == TypeConversion.Implicit) {
        return TypeConversion.Implicit;
      }

      return TypeConversion.None;
    }

    var toReference = to as ReferenceType;
    if (referencedType.conversionTo(toReference.referencedType) ==
        TypeConversion.NoConversion) {
      // No conversion will actually take place, so this is fine.
      return TypeConversion.NoConversion;
    }

    // Nothing else is legal.
    return TypeConversion.None;
  }

  @override
  TypedValue convertObjectTo(TypedValue object, ValueType endType) {
    assertConvertibleTo(endType);

    var conversion = conversionTo(endType);

    if (conversion == TypeConversion.NoConversion) {
      return object;
    }

    if (conversion == TypeConversion.Implicit) {
      // Implicit reference conversions are only ever while dereferencing.
      return referencedType.convertObjectTo(
          object.get() as TypedValue, endType);
    }

    throw RuntimeError('There are no explicit reference conversions.');
  }

  @override
  String toString() {
    return '@($referencedType)';
  }
}
