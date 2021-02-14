import 'Concepts.dart';

class Store {
  final _contents = <String, Evaluable>{};
  final Store _parent;

  static var stack = <Store>[Store(null)];

  Store(this._parent);
  static Store current() => stack.last;

  void add(String name, Evaluable item) {
    if (hasLocal(name)) {
      throw Exception('$name already exists in this scope.');
    }

    _contents[name] = item;
  }

  Evaluable get(String name) {
    if (!has(name)) {
      if (_parent != null) {
        return _parent.get(name);
      }

      throw Exception('Undeclared identifier $name.');
    }

    return _contents[name];
  }

  T getAs<T>(String name) {
    var evaluable = get(name);

    if (evaluable is T) {
      return evaluable as T;
    }

    return null;
  }

  void set(String name, TypedValue value) {
    if (!hasLocal(name)) {
      // Try the parent (if there is one).
      if (_parent != null) {
        _parent.set(name, value);
        return;
      }

      throw Exception('Undeclared identifier $name.');
    }

    var variable = getAs<Variable>(name);
    if (variable == null) {
      throw Exception('Cannot set value of constant $name.');
    }

    variable.set(value);
  }

  bool has(String name) {
    return _contents.containsKey(name);
  }

  bool hasLocal(String name) {
    return _contents.containsKey(name);
  }

  /// Branches the current store off into another, and runs a block
  /// of code in the context of the new store. Nothing can be added to
  /// or removed from the parent store (although values may change).
  void branch(void Function(Store) toRun) {
    var child = Store(this);

    // Make current() return the child.
    stack.add(child);
    toRun(child);

    // We're leaving the scope, so remove the child.
    stack.removeLast();
  }
}