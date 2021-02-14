library standard;

import '../Concrete.dart';
import '../Expression.dart';
import '../Functions.dart';
import '../Store.dart';

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
