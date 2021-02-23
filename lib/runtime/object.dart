import 'handle.dart';
import 'store.dart';
import 'type.dart';
import 'value.dart';

class ClassObject extends Value {
  // Manages fields and methods.
  Store store;

  ClassObject(ClassType classType) {
    type = classType;
    store = classType.createObjectStore(this);
  }

  ClassObject.from(ClassObject other) {
    type = other.type;

    // TODO: Clone object internal storage on copy.
    store = other.store;
  }

  @override
  Handle instanceMember(String name) {
    return store.get(name);
  }

  @override
  Value copyValue() {
    return ClassObject.from(this);
  }

  @override
  bool equals(Value other) {
    // TODO: implement equals
    throw UnimplementedError();
  }

  @override
  bool greaterThan(Value other) {
    // TODO: implement greaterThan
    throw UnimplementedError();
  }

  @override
  bool lessThan(Value other) {
    // TODO: implement lessThan
    throw UnimplementedError();
  }
}
