import 'package:language/runtime/exception.dart';

import 'concrete.dart';

abstract class NewStatement implements Statement {
  @override
  bool isStatic;

  NewStatement(this.isStatic);

  @override
  SideEffect execute();
}

/// A statement which is always dynamic (may never be static).
abstract class DynamicStatement extends NewStatement {
  DynamicStatement() : super(false);

  @override
  set isStatic(value) {
    if (value) {
      throw RuntimeError('Cannot make static DynamicStatement!');
    }
  }
}

abstract class StaticStatement extends NewStatement {
  StaticStatement() : super(true);

  @override
  set isStatic(value) {
    if (!value) {
      throw RuntimeError('Cannot make dynamic StaticStatement!');
    }
  }
}

abstract class ClassChild extends NewStatement {
  ClassChild(bool isStatic) : super(isStatic);
}

abstract class FunctionChild extends DynamicStatement {}

abstract class LoopChild extends DynamicStatement {}
