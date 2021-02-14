import 'Concepts.dart';
import 'Expression.dart';
import 'Store.dart';
import 'Util.dart';

class IntegerValue extends TypedValue implements Value {
  int value;

  IntegerValue(String string) : value = int.parse(string);

  @override
  String toString() => value.toString();

  @override
  Value get() => this;
}

class StringValue extends TypedValue implements Value {
  String value;

  StringValue(this.value);

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

  ReferenceType.of(this._referencedType);

  @override
  bool canConvertTo(ValueType other) {
    return _referencedType.canConvertTo(other);
  }
}

/// Essentially a pointer, but with added safety and with custom
/// syntax to increase clarity. Behaves like a variable when used
/// like one (with normal syntax).
class Reference extends Variable {
  Variable _referenced;

  Reference(TypedValue value)
      : super(ReferenceType.of(value.type), value.get()) {
    // TODO: Implement
    throw UnimplementedError();
    // _referenced =
  }

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

class FunctionType extends ValueType {
  ValueType returnType;
  var parameterTypes = <ValueType>[];

  FunctionType();

  FunctionType.forFunction(FunctionValue function) {
    returnType = function.returnType;
    parameterTypes = function.parameters.values.toList();
  }

  /// Can be used to match call signatures but also function objects.
  @override
  bool canConvertTo(ValueType other) {
    if (!(other is FunctionType)) {
      return false;
    }

    var otherFunction = other as FunctionType;

    // Return types must be compatible.
    if (!otherFunction.returnType.canConvertTo(returnType)) {
      return false;
    }

    // Can't match types if the number of parameters is different.
    if (otherFunction.parameterTypes.length != parameterTypes.length) {
      return false;
    }

    // Check if all the parameters match.
    for (var i = 0; i < parameterTypes.length; ++i) {
      if (!otherFunction.parameterTypes[i].canConvertTo(parameterTypes[i])) {
        return false;
      }
    }

    return true;
  }
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

class FunctionValue extends TypedValue implements Value {
  final String name;
  final ValueType returnType;
  final Map<String, ValueType> parameters;
  final List<Statement> _statements;

  FunctionValue(this.name, this.returnType, this._statements)
      : parameters = <String, ValueType>{};

  void addParameter(String name, ValueType type) {
    parameters[name] = type;
  }

  /// Sets the function's type. Should be done after all changes
  /// have been made.
  void applyType() {
    type = FunctionType.forFunction(this);
  }

  @override
  Value get() {
    return this;
  }

  TypedValue call(Map<String, Value> arguments) {
    TypedValue returnedValue;

    // Open a new scope for the function body to run inside.
    Store.current().branch((store) {
      // Bring the argument values into scope.
      for (var name in arguments.keys) {
        store.add(name, arguments[name]);

        // Set the type from our parameters types.
        store.getAs<TypedValue>(name).type = parameters[name];
      }

      // Execute the statements.
      for (var statement in _statements) {
        var sideEffects = statement.execute();

        // Check the side effects for stuff we need to handle.
        if (sideEffects != null) {
          if (sideEffects.returns) {
            returnedValue = sideEffects.returnedValue;

            // Stop executing the statements - we're returning.
            break;
          }
        }
      }

      // Cleanup is automatic, because the locals are lost when
      //  the scope is closed.
    });

    return returnedValue;
  }
}
