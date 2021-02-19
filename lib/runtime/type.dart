import 'package:language/runtime/concrete.dart';

import 'abstract.dart';
import 'exception.dart';

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
  @override
  ValueType get type => TypeOfType.shared;

  /// Returns a [TypeConversion] value indicating the style of conversion
  /// that may take place between this type and the type [to].
  TypeConversion conversionTo(ValueType to);

  static bool isConversionImplicit(TypeConversion conversion) {
    return conversion == TypeConversion.Implicit ||
        conversion == TypeConversion.NoConversion;
  }

  void assertConvertibleTo(ValueType endType) {
    if (conversionTo(endType) == TypeConversion.None) {
      throw RuntimeError('Cannot convert from "$this" to "$endType".');
    }
  }

  Value convertObjectTo(Value object, ValueType endType);

  Value convertObjectFrom(Value object, ValueType startType) {
    throw UnimplementedError('cOF');
  }

  @override
  bool equals(Evaluable other) {
    return conversionTo(other) == TypeConversion.None;
  }

  @override
  bool greaterThan(Evaluable other) {
    return hashCode > other.hashCode;
  }

  @override
  bool lessThan(Evaluable other) {
    return hashCode < other.hashCode;
  }
}

/// The type of value types.
class TypeOfType extends ValueType {
  static TypeOfType shared = TypeOfType();

  @override
  TypeConversion conversionTo(ValueType to) {
    if (to == this || to is AnyType) {
      return TypeConversion.NoConversion;
    }

    return TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }

  @override
  Value copy() {
    return this;
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
  Value copy() {
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
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }
}

class AnyType extends ValueType {
  @override
  Value copy() {
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
  Value convertObjectTo(Value object, ValueType endType) {
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
  Value copy() {
    return NoType();
  }

  /// [NoType] is likely to be printed in errors, but 'proc'
  /// doesn't make sense in all errors (e.g. you can't return
  /// 'proc' from a function), so we can specify a different
  /// name to use.
  String _name;

  NoType({String name = 'proc'}) {
    _name = name;
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    return to is NoType ? TypeConversion.NoConversion : TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }

  @override
  String toString() {
    return _name;
  }
}

enum Primitive { Int, String }

class PrimitiveType extends ValueType {
  final Primitive _type;

  static PrimitiveType get integer => PrimitiveType(Primitive.Int);

  static PrimitiveType get string => PrimitiveType(Primitive.String);

  PrimitiveType(this._type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PrimitiveType &&
              runtimeType == other.runtimeType &&
              _type == other._type;

  @override
  int get hashCode => _type.hashCode;

  @override
  Value copy() {
    return PrimitiveType(_type);
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    if (this == to || to is AnyType) {
      return TypeConversion.NoConversion;
    }

    return TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
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
  Value copy() {
    return ReferenceType.forReferenceTo(referencedType.copy());
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
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);

    var conversion = conversionTo(endType);

    if (conversion == TypeConversion.NoConversion) {
      return object;
    }

    if (conversion == TypeConversion.Implicit) {
      // Implicit reference conversions are only ever while dereferencing.
      return referencedType.convertObjectTo(object.get(), endType);
    }

    throw RuntimeError('There are no explicit reference conversions.');
  }

  @override
  String toString() {
    return '@($referencedType)';
  }
}

class ArrayType extends ValueType {
  final ValueType _elementType;

  ArrayType(this._elementType);

  @override
  TypeConversion conversionTo(ValueType to) {
    if (!(to is ArrayType)) {
      return TypeConversion.None;
    }

    var toElement = (to as ArrayType)._elementType;
    var elementConversion = _elementType.conversionTo(toElement);

    if (elementConversion != TypeConversion.NoConversion) {
      return TypeConversion.None;
    }

    return TypeConversion.NoConversion;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);

    var array = object as ArrayValue;
    var arrayType = endType as ArrayType;

    return ArrayValue(
        endType,
        array.elements
            .map((e) => e.mustConvertTo(arrayType._elementType))
            .toList());
  }

  @override
  Value copy() {
    return ArrayType(_elementType.copy());
  }

  @override
  String toString() {
    return '$_elementType[]';
  }
}
