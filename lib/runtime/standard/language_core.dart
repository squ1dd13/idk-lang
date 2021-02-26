library standard;

import 'package:language/runtime/exception.dart';
import 'package:language/runtime/primitive.dart';
import 'package:language/runtime/standard/interop.dart';
import 'package:language/runtime/statements.dart';

import '../function.dart';
import '../scope.dart';
import '../type.dart';

void registerCore() {
  var printFunction = FunctionValue('print', NullType(), <Statement>[
    DartDynamicStatement(() {
      var argument = Scope.current().get('value').value;
      print(argument);

      return null;
    }, false)
  ])
    ..addParameter('value', AnyType())
    ..applyType();

  var fatalError = FunctionValue('fatal', NullType(), <Statement>[
    DartDynamicStatement(() {
      var argument = Scope.current().get('message').value;
      throw RuntimeError(argument.toString());
    }, false)
  ])
    ..addParameter('message', AnyType())
    ..applyType();

  Scope.current().add('print', printFunction.createConstant());
  Scope.current().add('fatal', fatalError.createConstant());

  Scope.current().add('int', PrimitiveType.integer.createConstant());
  Scope.current().add('String', PrimitiveType.string.createConstant());
  Scope.current().add('proc', NullType().createConstant());
  Scope.current().add('Any', AnyType().createConstant());
  Scope.current().add('Type', TypeOfType.shared.createConstant());
  Scope.current().add('null', NullType.nullHandle().value.createConstant());

  registerInteropFunctions();
}
