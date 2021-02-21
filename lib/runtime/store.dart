import 'abstract.dart';
import 'exception.dart';

class Store {
  final _contents = <String, Handle>{};
  final Store _parent;

  static var stack = <Store>[Store(null)];

  Store(this._parent);

  static Store current() => stack.last;

  void add(String name, Handle item) {
    if (has(name)) {
      throw RuntimeError('$name already exists in this scope.');
    }

    _contents[name] = item;
  }

  Handle get(String name) {
    if (!has(name)) {
      if (_parent != null) {
        return _parent.get(name);
      }

      throw RuntimeError('Undeclared identifier "$name".');
    }

    return _contents[name];
  }

  void set(String name, Handle handle) {
    get(name).value = handle.value;
  }

  bool has(String name) {
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
