import 'Concepts.dart';
import 'Exceptions.dart';
import 'Expression.dart';

class IntegerValue extends TypedValue implements Value {
  int value;

  IntegerValue.raw(this.value);

  IntegerValue(String string) : value = int.parse(string) {
    type = PrimitiveType(Primitive.Int);
  }

  @override
  String toString() => value.toString();

  @override
  Value get() => this;

  @override
  Evaluable copy() {
    return IntegerValue.raw(value);
  }
}

class StringValue extends TypedValue implements Value {
  String value;

  StringValue(this.value) {
    type = PrimitiveType(Primitive.String);
  }

  @override
  String toString() => value;

  @override
  Value get() => this;

  @override
  Evaluable copy() {
    return StringValue(value);
  }
}

class SideEffects {
  // TODO: "break n"
  bool breaks = false;
  bool continues = false;
  bool returns = false;
  TypedValue returnedValue;
}

/// A single unit of code which affects the program without
/// producing a value when finished.
class Statement {
  /// Doesn't return a value.
  final Expression _fullExpression;

  Statement(this._fullExpression);

  SideEffects execute() {
    _fullExpression.evaluate();
    return SideEffects();
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
}

/// Essentially a pointer, but with added safety and with custom
/// syntax to increase clarity. Behaves like a variable when used
/// like one (with normal syntax). Implements [Variable] so it can
/// provide a transparent but custom interface.
class Reference implements Variable {
  TypedValue _referenced;

  @override
  ValueType type;

  Reference(TypedValue value) {
    _referenced = value;
    type = ReferenceType.forReferenceTo(value.type);
  }

  @override
  Value get() {
    return _referenced.get();
  }

  @override
  void set(TypedValue source) {
    if (_referenced is Variable) {
      // Let _referenced handle the type checking.
      (_referenced as Variable).set(source);
    } else {
      throw RuntimeError(
          'Cannot set value through reference to non-variable value.');
    }
  }

  void redirect(TypedValue source) {
    if (!source.type.canConvertTo(type)) {
      throw RuntimeError(
          'Cannot redirect reference of type $type to value of type ${source.type}!');
    }

    _referenced = source;
  }

  @override
  Evaluable copy() {
    return Reference(_referenced);
  }
}

enum Primitive {
  Int,
  String,
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
}
