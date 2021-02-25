import 'package:language/runtime/exception.dart';
import 'package:language/runtime/statements.dart';
import 'package:language/runtime/type.dart';

import 'handle.dart';
import 'scope.dart';
import 'value.dart';

class Space extends Value {
  final _scope = Scope(Scope.current());

  Space(List<StaticStatement> statements) {
    _scope.enter();
    statements.forEach((element) => element.execute());
    _scope.leave();
  }

  @override
  Handle staticMember(String name) {
    return _scope.getOwn(name);
  }

  @override
  ValueType get type => NullType.untypedNull();

  @override
  set type(ValueType value) {
    throw RuntimeError('Cannot set space type.');
  }

  @override
  Value copyValue() {
    throw RuntimeError('Cannot copy spaces.');
  }

  @override
  bool equals(Value other) {
    throw RuntimeError('Cannot compare spaces.');
  }

  @override
  bool greaterThan(Value other) {
    throw RuntimeError('Cannot compare spaces.');
  }

  @override
  bool lessThan(Value other) {
    throw RuntimeError('Cannot compare spaces.');
  }
}
