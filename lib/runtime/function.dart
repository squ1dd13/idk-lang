import 'concrete.dart';
import 'exception.dart';
import 'handle.dart';
import 'scope.dart';
import 'statements.dart';
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
  bool equals(Value other) {
    if (!(other is FunctionType)) {
      return false;
    }

    var otherFunction = other as FunctionType;

    if (!returnType.equals(otherFunction.returnType)) {
      return false;
    }

    if (otherFunction.parameterTypes.length != parameterTypes.length) {
      return false;
    }

    // Check if all the parameters match.
    for (var i = 0; i < parameterTypes.length; ++i) {
      if (!otherFunction.parameterTypes[i].equals(parameterTypes[i])) {
        return false;
      }
    }

    return true;
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

abstract class Callable extends Value {
  Map<String, ValueType> parameters;
  ValueType returnType;

  Callable([this.parameters, this.returnType]);

  Handle call(Map<String, Handle> arguments);
}

class FunctionValue extends Callable {
  String name;
  List<Statement> _statements;
  Scope Function() _getExecutionScope = () => Scope.current();

  var isOverride = false;

  FunctionValue.empty();

  FunctionValue(this.name, ValueType returnType, this._statements,
      [this.isOverride = false])
      : super(<String, ValueType>{}, returnType);

  FunctionValue.implemented(
      int parameterCount, SideEffect Function(List<Handle>) implementation,
      {String named, ValueType returns}) {
    name = named ?? 'closure_${implementation.hashCode}';
    returnType = returns ?? AnyType();

    parameters = <String, ValueType>{};
    for (var i = 0; i < parameterCount; ++i) {
      parameters['arg$i'] = AnyType();
    }

    _statements = [
      DartDynamicStatement(() {
        var arguments = List<Handle>.filled(parameterCount, null);

        for (var i = 0; i < parameterCount; ++i) {
          arguments[i] = Scope.current().get('arg$i');
        }

        return implementation(arguments);
      }, false)
    ];

    applyType();
  }

  void addParameter(String name, ValueType type) {
    parameters[name] = type;
  }

  /// Sets the function's type. Should be done after all changes
  /// have been made.
  void applyType() {
    type = FunctionType(this);
  }

  /// Returns a shallow copy of this function value which is always executed
  /// in a branch of [scope] rather than of `Scope.current()`.
  FunctionValue wrappedForScope(Scope scope) {
    var wrapped = FunctionValue.empty();
    wrapped.name = name;
    wrapped.returnType = returnType;
    wrapped.type = type;
    wrapped.parameters = parameters;
    wrapped._statements = _statements;
    wrapped._getExecutionScope = () => scope;

    return wrapped;
  }

  static List<dynamic> runStatement(Statement statement) {
    var sideEffect = statement.execute();

    // Check the side effects for stuff we need to handle.
    if (sideEffect != null) {
      if (sideEffect.isLoopInterrupt) {
        // Being able to break or continue loops across function boundaries
        //  seems like a very bad idea, so let's disallow it.
        var interruptedName = sideEffect.continueName ?? sideEffect.breakName;

        throw RuntimeError(
            'Interrupting loops across function boundaries is disallowed. '
            '(No parent loop matching the name "$interruptedName" was '
            'found.)');
      }

      if (sideEffect.returned != null) {
        // Stop executing the statements - we're returning.
        return [false, sideEffect.returned];
      }
    }

    return [true, null];
  }

  @override
  Handle call(Map<String, Handle> arguments) {
    var returnedHandle = NullType.nullHandle();

    var executionParentScope = _getExecutionScope();

    // Open a new scope for the function body to run inside.
    executionParentScope.branch((scope) {
      for (var name in arguments.keys) {
        var copied = arguments[name].copyHandle();
        scope.add(name, copied.convertHandleTo(parameters[name]));
      }

      // Execute the body.
      for (var statement in _statements) {
        var result = runStatement(statement);

        if (!result[0]) {
          returnedHandle = result[1];
          break;
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
