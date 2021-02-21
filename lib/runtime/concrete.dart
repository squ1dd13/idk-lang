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

/// A single unit of code which affects the program without
/// producing a value when finished.
class Statement {
  /// Doesn't return a value.
  final Expression _fullExpression;

  Statement(this._fullExpression);

  SideEffect execute() {
    _fullExpression.evaluate();
    return SideEffect.nothing();
  }
}

class SideEffectStatement extends Statement {
  final SideEffect Function() _action;

  SideEffectStatement(this._action) : super(null);

  @override
  SideEffect execute() {
    return _action();
  }
}
