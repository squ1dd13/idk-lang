library standard;

import '../concrete.dart';
import '../expression.dart';
import '../function.dart';
import '../store.dart';
import '../type.dart';

void registerIO() {
  var printFunction = FunctionValue('print', NoType(), <Statement>[
    Statement(InlineExpression(() {
      var argument = Store.current().get('value').get();
      print(argument);

      return null;
    }))
  ]);

  printFunction.addParameter('value', AnyType());
  printFunction.applyType();

  Store.current().add('print', printFunction);
}
