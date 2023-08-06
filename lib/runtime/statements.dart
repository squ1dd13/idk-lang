import 'package:language/runtime/exception.dart';

import 'concrete.dart';

abstract class Statement {
  bool isStatic;

  Statement(this.isStatic);

  SideEffect? execute();
}

class DartDynamicStatement implements DynamicStatement {
  @override
  bool isStatic;

  final SideEffect? Function() _action;

  DartDynamicStatement(this._action, this.isStatic);

  @override
  SideEffect? execute() {
    return _action();
  }
}

/// A statement which is always dynamic (may never be static).
abstract class DynamicStatement extends Statement {
  DynamicStatement() : super(false);

  @override
  set isStatic(value) {
    if (value) {
      throw RuntimeError('Cannot make static DynamicStatement!');
    }
  }
}

abstract class StaticStatement extends Statement {
  StaticStatement() : super(true);

  @override
  set isStatic(value) {
    if (!value) {
      throw RuntimeError('Cannot make dynamic StaticStatement!');
    }
  }
}

abstract class ClassChild extends Statement {
  ClassChild(bool isStatic) : super(isStatic);
}

abstract class FunctionChild extends DynamicStatement {}

abstract class LoopChild extends DynamicStatement {}
