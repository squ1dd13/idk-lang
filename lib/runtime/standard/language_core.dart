library standard;

import 'package:language/runtime/exception.dart';

import '../concrete.dart';
import '../expression.dart';
import '../function.dart';
import '../store.dart';
import '../type.dart';

void registerCore() {
  var printFunction = FunctionValue('print', NoType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('value').get();
      print(argument);

      return null;
    }))
  ])
    ..addParameter('value', AnyType())
    ..applyType();

  var fatalError = FunctionValue('fatal', NoType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('message').get();
      throw RuntimeError(argument.toString());
    }))
  ])
    ..addParameter('message', AnyType())
    ..applyType();

  Store.current().add('print', printFunction);
  Store.current().add('fatal', fatalError);

  Store.current().add('int', PrimitiveType.integer);
  Store.current().add('string', PrimitiveType.string);
  Store.current().add('proc', NoType());
  Store.current().add('any', AnyType());
}
