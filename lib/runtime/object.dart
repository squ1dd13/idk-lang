import 'function.dart';
import 'handle.dart';
import 'scope.dart';
import 'statements.dart';
import 'type.dart';
import 'value.dart';

/// A class type. Equality is determined by name.
class ClassType extends ValueType implements Callable {
  final String name;
  final List<Statement> _setupStatements;
  final Handle superclass;
  final bool abstract;
  final Scope statics;
  ClassType _complex;

  static var classTypeStack = <ClassType>[];

  ClassType(this.name, this._setupStatements, this.abstract, this.superclass)
      : statics = Scope(Scope.current()) {
    statics.enter();
    classTypeStack.add(this);

    // Execute static statements so that they affect the static scope.
    for (var statement in _setupStatements) {
      if (statement.isStatic) {
        statement.execute();
      }
    }

    classTypeStack.removeLast();
    statics.leave();

    // We won't need to execute these again.
    _setupStatements.removeWhere((element) => element.isStatic);
  }

  @override
  Handle staticMember(String name) {
    return statics.get(name);
  }

  @override
  bool equals(Value other) {
    // TODO: Prevent classes with same names being equal unless they are actually the same class.
    return other is ClassType && name == other.name;
  }

  Scope createObjectScope(ClassObject object, {bool asSuper = false}) {
    Scope scope;

    if (superclass != null) {
      var superInstance = ClassObject(superclass.value as ClassType);

      scope = Scope(superInstance.scope);
      scope.add('super', superInstance.createHandle());
    }

    // If we don't have one already, create a new scope.
    scope ??= Scope(Scope.global());

    scope.enter();

    for (var statement in _setupStatements) {
      // TODO: Handle exceptions in populate().
      statement.execute();
    }

    // Wrap all functions. We check handleType because it only gives us real
    //  functions rather than references to functions, and we know that all the
    //  actual functions are not references (whereas function variables must be
    //  references).
    var functionPredicate = (handle) => handle.handleType is FunctionType;

    var functions = scope.matching(functionPredicate);

    for (var i = 0; i < functions.length; ++i) {
      var functionValue = functions[i].value as FunctionValue;
      functions[i].value = functionValue.wrappedForScope(scope);

      var functionName = functionValue.name;
      var current = scope.parent;

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
    scope.add('self', object.createHandle());

    scope.leave();

    return scope;
  }

  @override
  String toString() {
    return name;
  }

  bool inheritsFrom(ClassType other) {
    var parentClass = superclass;
    var otherHandle = other.createHandle();

    while (parentClass != null) {
      if (parentClass.equals(otherHandle)) {
        return true;
      }

      parentClass = (parentClass.value as ClassType).superclass;
    }

    return false;
  }

  @override
  Map<String, ValueType> get parameters =>
      (staticMember('').value as Callable).parameters;

  @override
  ValueType get returnType => this;

  @override
  Handle call(Map<String, Handle> arguments) {
    return (staticMember('').value as Callable)(arguments);
  }

  @override
  set parameters(Map<String, ValueType> _parameters) {
    // TODO: implement parameters
    throw UnimplementedError();
  }

  @override
  set returnType(ValueType _returnType) {
    // TODO: implement returnType
    throw UnimplementedError();
  }

  @override
  Handle createHandle() {
    // If we have a complex type, return a handle to that. Otherwise, just
    //  return a handle to this object.
    return _complex?.createHandle() ?? super.createHandle();
  }

  @override
  Handle createConstant() {
    return _complex?.createConstant() ?? super.createConstant();
  }
}

class ClassObject extends Value {
  // Manages fields and methods.
  Scope scope;
  Handle complexType;

  ClassObject(ClassType classType) {
    complexType = classType.createHandle();

    type = classType;
    scope = classType.createObjectScope(this);
  }

  ClassObject.from(ClassObject other) {
    type = other.type;

    // TODO: Clone object internal storage on copy.
    scope = other.scope;
  }

  @override
  Handle instanceMember(String name) {
    return scope.get(name);
  }

  @override
  Value copyValue() {
    return ClassObject.from(this);
  }

  @override
  bool equals(Value other) {
    // TODO: implement equals
    throw UnimplementedError();
  }

  @override
  bool greaterThan(Value other) {
    // TODO: implement greaterThan
    throw UnimplementedError();
  }

  @override
  bool lessThan(Value other) {
    // TODO: implement lessThan
    throw UnimplementedError();
  }
}
