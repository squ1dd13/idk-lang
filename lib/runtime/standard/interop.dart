import 'dart:mirrors';

import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/function.dart';
import 'package:language/runtime/handle.dart';
import 'package:language/runtime/primitive.dart';
import 'package:language/runtime/scope.dart';
import 'package:language/runtime/type.dart';
import 'package:language/runtime/value.dart';

class DartType extends ValueType {
  final DartObject _dartObject;

  DartType(Type _theType) : _dartObject = DartObject(_theType);

  @override
  Handle staticMember(String name) {
    // Static members are instance members on types.
    return _dartObject.instanceMember(name);
  }

  @override
  bool equals(Value? other) {
    return other is DartType && _dartObject.equals(other._dartObject);
  }
}

ValueType _dartToLanguageType(Type type) {
  if (type == String) {
    return PrimitiveType.string;
  }

  if (type == int) {
    return PrimitiveType.integer;
  }

  if (type == bool) {
    return PrimitiveType.boolean;
  }

  return DartType(type);
}

Handle _dartToLanguageHandle(Handle handle, ValueType? endType) {
  var handleType = handle.handleType!;

  if (handleType.equals(endType)) {
    return handle;
  }

  if (endType!.equals(AnyType.any)) {
    return handle;
  }

  if (endType is PrimitiveType) {
    var instance = (handle.value as DartObject)._dartInstance;

    switch (endType.primitive) {
      case Primitive.Int:
        return IntegerValue.raw(instance).createHandle();
      case Primitive.String:
        return StringValue(instance.toString()).createHandle();
      case Primitive.Bool:
        return BooleanValue(instance as bool?).createHandle();
    }

    throw Exception('wtf');
  }

  if (endType.equals(PrimitiveType.integer)) {
    if (handleType.notEquals(PrimitiveType.integer)) {
      throw RuntimeError('Type mismatch: not of integer type.');
    }

    var instance = (handle.value as DartObject)._dartInstance as int?;
    return DartObject(instance).createHandle();
  }

  if (endType.equals(PrimitiveType.boolean)) {
    if (handleType.notEquals(PrimitiveType.boolean)) {
      throw RuntimeError('Type mismatch: not of Boolean type.');
    }

    var instance = (handle.value as DartObject)._dartInstance as bool?;
    return DartObject(instance).createHandle();
  }

  throw RuntimeError('Unable to convert from $handleType to $endType.');
}

class FieldHandle extends Handle {
  final DartObject _parent;
  final Symbol _name;

  FieldHandle(this._parent, String name) : _name = Symbol(name);

  @override
  Value get value {
    return _dartToLanguageValue(
        _parent._mirror.getField(_name).reflectee, _parent._mirror);
  }

  @override
  set value(Value newValue) {
    var dartValue = DartObject.from(newValue.createHandle())._dartInstance;
    _parent._mirror.setField(_name, dartValue);
  }

  @override
  Handle convertHandleTo(ValueType? endType) {
    return _dartToLanguageHandle(this, endType);
  }

  @override
  Handle convertValueTo(ValueType? endType) {
    return convertHandleTo(endType);
  }

  @override
  Handle copyHandle() {
    return this;
  }

  @override
  ValueType get handleType =>
      _dartToLanguageType(_parent._dartInstance.runtimeType);

  @override
  ValueType get valueType => handleType;
}

Value _dartToLanguageValue(dynamic dartThing, [dynamic parent]) {
  var mirror = reflect(dartThing);

  // Convert functions into something we can call.
  if (mirror is ClosureMirror) {
    var function = mirror.function;

    var name = function.simpleName;
    var returnType = _dartToLanguageType(function.returnType.reflectedType);

    var parameters = <String?, ValueType?>{};

    for (var i = 0; i < function.parameters.length; ++i) {
      var type = _dartToLanguageType(function.parameters[i].type.reflectedType);
      parameters['arg$i'] = type;
    }

    var functionValue =
        FunctionValue.implemented(function.parameters.length, (argHandles) {
      var arguments = List<dynamic>.filled(parameters.length, null);

      for (var i = 0; i < parameters.length; ++i) {
        var handle = argHandles[i]!;

        var dartValue = DartObject.from(handle)._dartInstance;

        arguments[i] = dartValue;
      }

      var owner = parent as ObjectMirror; //function.owner as ObjectMirror;
      var returnValue = owner.invoke(name, arguments);

      return SideEffect.returns(
          _dartToLanguageValue(returnValue.reflectee).createHandle());
    }, named: name.toString(), returns: returnType);

    functionValue.parameters = parameters;
    functionValue.applyType();

    return functionValue;
  }

  return DartObject(dartThing);
}

class DartObject extends Value {
  dynamic _dartInstance;
  dynamic _mirror;

  @override
  ValueType get type => DartType(_dartInstance.runtimeType);

  DartObject(this._dartInstance) {
    if (_dartInstance is Type) {
      _mirror = reflectType(_dartInstance as Type);
      return;
    }

    _mirror = reflect(_dartInstance);
  }

  DartObject.from(Handle handle) {
    // For Dart objects, we can just get the Dart instance and use that.
    if (handle.value is DartObject) {
      _dartInstance = (handle.value as DartObject)._dartInstance;
      _mirror = reflect(_dartInstance);

      return;
    }

    // The only other objects we can create Dart ones from are primitives.
    if (!(handle.valueType is PrimitiveType)) {
      throw RuntimeError(
          'Cannot convert "${handle.valueType}" to Dart object.');
    }

    _dartInstance = (handle.value as PrimitiveValue).rawValue;
    _mirror = reflect(_dartInstance);
  }

  @override
  Value mustConvertTo(ValueType? endType) {
    return _dartToLanguageHandle(createHandle(), endType).value;
  }

  @override
  Handle instanceMember(String name) {
    return FieldHandle(this, name);
  }

  @override
  Value copyValue() {
    return this;
  }

  @override
  bool equals(Value? other) {
    return other is DartObject && _dartInstance == other._dartInstance;
  }

  @override
  bool greaterThan(Value other) {
    return other is DartObject && _dartInstance > other._dartInstance;
  }

  @override
  bool lessThan(Value other) {
    return other is DartObject && _dartInstance < other._dartInstance;
  }

  @override
  String toString() => _dartInstance.toString();
}

void registerInteropFunctions() {
  Scope.current().add(
      'makeDart',
      FunctionValue.implemented(1, (arguments) {
        return SideEffect.returns(
            _dartToLanguageValue(DartObject.from(arguments[0]!)._dartInstance)
                .createHandle());
      }, named: 'makeDart')
          .createHandle());
}
