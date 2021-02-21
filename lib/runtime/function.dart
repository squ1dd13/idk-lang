import 'concrete.dart';
import 'exception.dart';
import 'handle.dart';
import 'store.dart';
import 'type.dart';
import 'value.dart';

class FunctionType extends ValueType {
  ValueType returnType;
  var parameterTypes = <ValueType>[];

  FunctionType(FunctionValue function) {
    returnType = function.returnType;
    parameterTypes = function.parameters.values.toList();
  }

  FunctionType.build(this.returnType, this.parameterTypes);

  @override
  Value copyValue() {
    return FunctionType.build(
        returnType.copyValue(), parameterTypes.map((type) => type.copyValue()));
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
    if (!ValueType.isConversionImplicit(
        otherFunction.returnType.conversionTo(returnType))) {
      return TypeConversion.None;
    }

    // Can't match types if the number of parameters is different.
    if (otherFunction.parameterTypes.length != parameterTypes.length) {
      return TypeConversion.None;
    }

    // Check if all the parameters match.
    for (var i = 0; i < parameterTypes.length; ++i) {
      if (!ValueType.isConversionImplicit(
          otherFunction.parameterTypes[i].conversionTo(parameterTypes[i]))) {
        return TypeConversion.None;
      }
    }

    // No conversion will take place.
    return TypeConversion.NoConversion;
  }

  @override
  Value convertObjectTo(Value object, ValueType endType) {
    return object;
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

class FunctionValue extends Value {
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
    type = FunctionType(this);
  }

  Handle call(Map<String, Handle> arguments) {
    var returnedHandle = NullType.nullHandle();

    // Open a new scope for the function body to run inside.
    Store.current().branch((store) {
      for (var name in arguments.keys) {
        var copied = arguments[name].copyHandle();
        store.add(name, copied.convertHandleTo(parameters[name]));
      }

      // Execute the body.
      for (var statement in _statements) {
        var sideEffect = statement.execute();

        // Check the side effects for stuff we need to handle.
        if (sideEffect != null) {
          if (sideEffect.isLoopInterrupt) {
            // Being able to break or continue loops across function boundaries
            //  seems like a very bad idea, so let's disallow it.
            var interruptedName =
                sideEffect.continueName ?? sideEffect.breakName;

            throw RuntimeError(
                'Interrupting loops across function boundaries is disallowed. '
                '(No parent loop matching the name "$interruptedName" was '
                'found.)');
          }

          if (sideEffect.returned != null) {
            returnedHandle = sideEffect.returned;

            // Stop executing the statements - we're returning.
            break;
          }
        }
      }

      // Cleanup is automatic, because the locals are lost when
      //  the scope is closed.
    });

    return returnedHandle.convertHandleTo(returnType);
  }

  @override
  Value copyValue() {
    throw RuntimeError('Copying functions is not allowed.');
  }

  @override
  bool equals(Value other) {
    if (!(other is FunctionValue)) {
      return false;
    }

    var function = other as FunctionValue;
    return name == function.name &&
        returnType == function.returnType &&
        parameters == function.parameters &&
        _statements == function._statements;
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
