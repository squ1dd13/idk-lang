import 'Concepts.dart';
import 'Exceptions.dart';
import 'Expression.dart';
import 'Types.dart';

class IntegerValue extends Value {
  int value;

  IntegerValue.raw(this.value) {
    type = PrimitiveType(Primitive.Int);
  }

  IntegerValue(String string) : value = int.parse(string) {
    type = PrimitiveType(Primitive.Int);
  }

  @override
  String toString() => value.toString();

  @override
  Value get() => this;

  @override
  Value copy() {
    return IntegerValue.raw(value);
  }
}

class StringValue extends Value {
  String value;

  StringValue(this.value) {
    type = PrimitiveType(Primitive.String);
  }

  @override
  String toString() => value;

  @override
  Value get() => this;

  @override
  Value copy() {
    return StringValue(value);
  }
}

class SideEffects {
  // TODO: "break n"
  bool breaks = false;
  bool continues = false;
  bool returns = false;
  Value returnedValue;
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

/// Essentially a pointer, but with added safety and with custom
/// syntax to increase clarity. Behaves like a variable when used
/// like one (with normal syntax). Implements [Variable] so it can
/// provide a transparent but custom interface.
class Reference extends Value implements Variable {
  Value _referenced;

  @override
  ValueType type;

  Reference(Value value) {
    _referenced = value;
    type = ReferenceType.forReferenceTo(value.type);
  }

  @override
  Value get() {
    return _referenced.get();
  }

  @override
  void set(Value source) {
    if (_referenced is Variable) {
      // Let _referenced handle the type checking.
      (_referenced as Variable).set(source);
    } else {
      throw RuntimeError(
          'Cannot set value through reference to non-variable value.');
    }
  }

  void redirect(Value source) {
    if (source.type.conversionTo(type) != TypeConversion.None) {
      throw RuntimeError('Cannot redirect reference of type $type '
          'to value of type ${source.type}!');
    }

    _referenced = source;
  }

  @override
  Value copy() {
    // Note that we don't copy _referenced.
    return Reference(_referenced);
  }
}

enum Primitive { Int, String }
