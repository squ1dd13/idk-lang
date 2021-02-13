import 'Concepts.dart';
import 'Expression.dart';
import 'Util.dart';

class IntegerValue extends Value {
  int value;

  IntegerValue(String string) : value = int.parse(string);

  @override
  String toString() => value.toString();
}

class StringValue extends Value {
  String value;

  StringValue(this.value);

  @override
  String toString() => value;
}

class SideEffects {
  // TODO: "break n"
  bool breaks;
  bool continues;
  bool returns;
  TypedValue returnedValue;
}

/// A single unit of code which affects the program without
/// producing a value when finished.
class Statement {
  /// Doesn't return a value.
  Expression _fullExpression;

  SideEffects execute() {
    _fullExpression.evaluate();
    return SideEffects();
  }
}

class ReferenceType extends ValueType {
  ValueType _referencedType;

  @override
  bool canTakeFrom(ValueType other) {
    return _referencedType.canTakeFrom(other);
  }
}

/// Essentially a pointer, but with added safety and with custom
/// syntax to increase clarity. Behaves like a variable when used
/// like one (with normal syntax).
class Reference extends Variable {
  Variable _referenced;

  @override
  Value get() {
    return _referenced.get();
  }

  @override
  void set(TypedValue source) {
    // Let _referenced handle the type checking.
    _referenced.set(source);
  }

  void redirect(TypedValue source) {
    if (!type.canTakeFrom(source.type)) {
      throw LogicException('Cannot redirect reference of type $type to value of type ${source.type}!');
    }

    _referenced = source;
  }
}

class FunctionValue extends Value {
  final String name;
  final List<Statement> _statements;

  FunctionValue(this.name, this._statements);
}