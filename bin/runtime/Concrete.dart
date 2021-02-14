import 'Concepts.dart';
import 'Expression.dart';
import 'Util.dart';

class IntegerValue extends TypedValue implements Value {
  int value;

  IntegerValue(String string) : value = int.parse(string) {
    type = PrimitiveType(Primitive.Int);
  }

  @override
  String toString() => value.toString();

  @override
  Value get() => this;
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
  final ValueType _referencedType;

  ReferenceType.forReferenceTo(this._referencedType);

  @override
  bool canConvertTo(ValueType other) {
    return _referencedType.canConvertTo(other);
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
      throw LogicException(
          'Cannot set value through reference to non-variable value.');
    }
  }

  void redirect(TypedValue source) {
    if (!source.type.canConvertTo(type)) {
      throw LogicException(
          'Cannot redirect reference of type $type to value of type ${source.type}!');
    }

    _referenced = source;
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
}

class AnyType extends ValueType {
  @override
  bool canConvertTo(ValueType other) {
    return true;
  }
}

class NoType extends ValueType {
  @override
  bool canConvertTo(ValueType other) {
    return false;
  }
}
