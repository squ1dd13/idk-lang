import 'Concepts.dart';
import 'Concrete.dart';
import 'Store.dart';
import 'Types.dart';

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

  @override
  Evaluable copy() {
    // TODO: implement copy
    throw UnimplementedError();
  }

  @override
  TypeConversion conversionTo(ValueType to) {
    if (to is AnyType) {
      return TypeConversion.NoConversion;
    }

    if (!(to is FunctionType)) {
      return TypeConversion.None;
    }

    var otherFunction = to as FunctionType;

    // Return types must be compatible.
    if (!otherFunction.returnType.canConvertTo(returnType)) {
      return TypeConversion.None;
    }

    // Can't match types if the number of parameters is different.
    if (otherFunction.parameterTypes.length != parameterTypes.length) {
      return TypeConversion.None;
    }

    // Check if all the parameters match.
    for (var i = 0; i < parameterTypes.length; ++i) {
      if (!otherFunction.parameterTypes[i].canConvertTo(parameterTypes[i])) {
        return TypeConversion.None;
      }
    }

    // No conversion will take place.
    return TypeConversion.NoConversion;
  }

  @override
  TypedValue convertObjectTo(TypedValue object, ValueType endType) {
    // TODO: implement convertObjectTo
    throw UnimplementedError();
  }

  @override
  String toString() {
    var buffer = StringBuffer(returnType.toString());
    buffer.write('(');
    buffer.writeAll(parameterTypes, ', ');
    buffer.write(')');

    return buffer.toString();
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

  TypedValue call(Map<String, Evaluable> arguments) {
    TypedValue returnedValue;

    // Open a new scope for the function body to run inside.
    Store.current().branch((store) {
      for (var name in arguments.keys) {
        // var argumentVariable = Variable(parameters[name], null);

        var typed = arguments[name].copy() as TypedValue;
        store.add(name, typed.type.convertObjectTo(typed, parameters[name]));
        // store.add(name, arguments[name].copy());
      }

      // Execute the body.
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

  @override
  Evaluable copy() {
    // TODO: implement copy
    throw UnimplementedError();
  }
}
