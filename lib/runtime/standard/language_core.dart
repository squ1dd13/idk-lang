library standard;

import 'package:language/runtime/exception.dart';
import 'package:language/runtime/primitive.dart';

import '../concrete.dart';
import '../expression.dart';
import '../function.dart';
import '../store.dart';
import '../type.dart';

void registerCore() {
  var printFunction = FunctionValue('print', NullType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('value').value;
      print(argument);

      return null;
    }))
  ])
    ..addParameter('value', AnyType())
    ..applyType();

  var fatalError = FunctionValue('fatal', NullType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('message').value;
      throw RuntimeError(argument.toString());
    }))
  ])
    ..addParameter('message', AnyType())
    ..applyType();

  Store.current().add('print', printFunction.createHandle());
  Store.current().add('fatal', fatalError.createHandle());

  Store.current().add('int', PrimitiveType.integer.createHandle());
  Store.current().add('string', PrimitiveType.string.createHandle());
  Store.current().add('proc', NullType().createHandle());
  Store.current().add('any', AnyType().createHandle());
  Store.current().add('Type', TypeOfType.shared.createHandle());
}
