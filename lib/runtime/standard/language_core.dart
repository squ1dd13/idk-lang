library standard;

import 'package:language/runtime/exception.dart';
import 'package:language/runtime/handle.dart';
import 'package:language/runtime/primitive.dart';

import '../concrete.dart';
import '../expression.dart';
import '../function.dart';
import '../store.dart';
import '../type.dart';

void registerCore() {
  var printFunction = FunctionValue('print', NoType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('value').value;
      print(argument);

      return null;
    }))
  ])
    ..addParameter('value', AnyType())
    ..applyType();

  var fatalError = FunctionValue('fatal', NoType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('message').value;
      throw RuntimeError(argument.toString());
    }))
  ])
    ..addParameter('message', AnyType())
    ..applyType();

  Store.current().add('print', Handle.create(printFunction));
  Store.current().add('fatal', Handle.create(fatalError));

  Store.current().add('int', Handle.create(PrimitiveType.integer));
  Store.current().add('string', Handle.create(PrimitiveType.string));
  Store.current().add('proc', Handle.create(NoType()));
  Store.current().add('any', Handle.create(AnyType()));
}
