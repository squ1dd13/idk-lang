import 'Concepts.dart';
import 'Concrete.dart';
import 'Store.dart';

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
      // Bring the argument values into scope but as new variables.
      // If we don't create variables here (just directly add the
      //  values instead), reading the argument values will work,
      //  but assigning to them could produce errors because there
      //  would be no guarantee that they could be assigned to.
      // If they could be assigned to, everything would be
      //  pass-by-reference, which is not what we want as a default.
      for (var name in arguments.keys) {
        store.add(name, Variable(parameters[name], arguments[name].get()));
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
}
