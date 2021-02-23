import 'package:language/runtime/function.dart';
import 'package:language/runtime/store.dart';

import 'array.dart';
import 'concrete.dart';
import 'exception.dart';
import 'handle.dart';
import 'object.dart';
import 'primitive.dart';
import 'value.dart';

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
  bool equals(Value other) {
    return conversionTo(other) == TypeConversion.None;
  }

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
  TypeConversion conversionTo(ValueType to) {
    if (to is TypeOfType || to is AnyType) {
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
  Value copyValue() {
    return this;
  }
}

/// A class type. Equality is determined by name.
class ClassType extends ValueType {
  final String name;
  final List<Statement> _setupStatements;
  final Handle superclass;
  final bool abstract;
  final Store statics;

  static var classTypeStack = <ClassType>[];

  ClassType(this.name, this._setupStatements, this.abstract, this.superclass)
      : statics = Store(Store.current()) {
    Store.current().add(name, createHandle());

    Store.stack.add(statics);
    classTypeStack.add(this);

    // Execute static statements so that they affect the static store.
    for (var statement in _setupStatements) {
      if (statement.isStatic) {
        statement.execute();
      }
    }

    classTypeStack.removeLast();
    Store.stack.removeLast();

    // We won't need to execute these again.
    _setupStatements.removeWhere((element) => element.isStatic);
  }

  @override
  Handle staticMember(String name) {
    return statics.get(name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassType &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  Value copyValue() {
    return ClassType(name, _setupStatements, abstract, superclass);
  }

  @override
  bool equals(Value other) {
    // TODO: Prevent classes with same names being equal unless they are actually the same class.
    return other is ClassType && name == other.name;
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    // The only 'conversion' that may take place is from this type to
    //  the same type, or to 'any'.
    if (equals(to) || to is AnyType) {
      return TypeConversion.NoConversion;
    }

    if (superclass != null) {
      return (superclass.value as ClassType).conversionTo(to);
    }

    return TypeConversion.None;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    assertConvertibleTo(endType);
    return object;
  }

  Store createObjectStore(ClassObject object, {bool asSuper = false}) {
    Store store;

    if (superclass != null) {
      var superInstance = ClassObject(superclass.value as ClassType);

      store = Store(superInstance.store);
      store.add('super', superInstance.createHandle());
    }

    // If we don't have one already, create a new store.
    store ??= Store(Store.global());

    Store.stack.add(store);

    for (var statement in _setupStatements) {
      // TODO: Handle exceptions in populate().
      statement.execute();
    }

    // Wrap all functions. We check handleType because it only gives us real
    //  functions rather than references to functions, and we know that all the
    //  actual functions are not references (whereas function variables must be
    //  references).
    var functionPredicate = (handle) => handle.handleType is FunctionType;

    var functions = store.matching(functionPredicate);

    for (var i = 0; i < functions.length; ++i) {
      var functionValue = functions[i].value as FunctionValue;
      functions[i].value = functionValue.wrappedForStore(store);

      var functionName = functionValue.name;
      var current = store.parent;

      // Move up through superclasses and override parent implementations
      //  for methods we define. If we don't do this, inherited methods will
      //  only ever call the implementation of a method defined on the same
      //  level as the level that implements the inherited method.
      while (current != null && current.has(functionName)) {
        // Override the parent's implementation for the function.
        current.set(functionName, functions[i]);

        current = current.parent;
      }
    }

    // Add 'self' so that it may be used in methods.
    store.add('self', object.createHandle());

    Store.stack.removeLast();

    return store;
  }

  @override
  String toString() {
    return name;
  }
}

class AnyType extends ValueType {
  @override
  Value copyValue() {
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
  TypeConversion conversionTo(ValueType to) {
    return to is NullType ? TypeConversion.NoConversion : TypeConversion.None;
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

class ReferenceType extends ValueType {
  final ValueType referencedType;

  ReferenceType.to(this.referencedType);

  @override
  Value copyValue() {
    return ReferenceType.to(referencedType.copyValue());
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
      return referencedType.convertObjectTo(object, endType);
    }

    throw RuntimeError('There are no explicit reference conversions.');
  }

  @override
  Value convertObjectFrom(Value object, ValueType startType) {
    if (object.type is ReferenceType) {
      var reference = object.type as ReferenceType;
      if (reference.referencedType.conversionTo(referencedType) ==
          TypeConversion.NoConversion) {
        return object;
      }

      throw RuntimeError('no');
    }
  }

  @override
  String toString() {
    return '@($referencedType)';
  }
}

/// 'any' but for elements from collection literals. We need
/// this class because we don't know the collection type
/// immediately, so we need a type we can convert to the real
/// element type as soon as we find it out.
class ElementType extends AnyType {
  @override
  TypeConversion conversionTo(ValueType to) {
    return TypeConversion.NoConversion;
  }

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
  TypeConversion conversionTo(ValueType to) {
    if (!(to is ArrayType)) {
      return TypeConversion.None;
    }

    var toElement = (to as ArrayType).elementType;
    var elementConversion = elementType.conversionTo(toElement);

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

    var mapped =
        array.elements.map((e) => e.convertHandleTo(arrayType.elementType));

    return ArrayValue(endType, mapped.toList());
  }

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
