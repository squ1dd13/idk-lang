import 'package:language/runtime/statements.dart';

import 'expression.dart';
import 'handle.dart';

class SideEffect {
  String breakName;
  String continueName;
  Handle returned;
  Handle thrown;

  SideEffect.nothing();

  SideEffect.breaks({String name = ''}) {
    breakName = name;
  }

  SideEffect.continues({String name = ''}) {
    continueName = name;
  }

  SideEffect.throws(this.thrown);

  SideEffect.returns(this.returned);

  bool continuesLoopName(String name) {
    // If the name is empty, we match any loop (the first loop that handles
    //  the effect). If the name is null, the effect is not present.
    return continueName != null &&
        (continueName.isEmpty || continueName == name);
  }

  bool breaksLoopName(String name) {
    return breakName != null && (breakName.isEmpty || breakName == name);
  }

  bool get isLoopInterrupt => breakName != null || continueName != null;

  bool get isInterrupt =>
      breakName != null ||
      continueName != null ||
      returned != null ||
      thrown != null;
}

class GenericStatement extends Statement implements FunctionChild, LoopChild {
  @override
  final Expression _fullExpression;

  GenericStatement(this._fullExpression, bool isStatic) : super(isStatic);

  @override
  SideEffect execute() {
    _fullExpression.evaluate();
    return SideEffect.nothing();
  }
}
