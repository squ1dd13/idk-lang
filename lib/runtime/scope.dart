import 'exception.dart';
import 'handle.dart';

class Scope {
  final _contents = <String, Handle>{};
  final Scope parent;

  static var stack = <Scope>[Scope(null)];

  Scope(this.parent);

  static Scope current() => stack.last;

  static Scope global() => stack.first;

  void add(String name, Handle item) {
    if (has(name)) {
      throw RuntimeError('$name already exists in this scope.');
    }

    _contents[name] = item;
  }

  Handle get(String name) {
    if (!has(name)) {
      if (parent != null) {
        return parent.get(name);
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

  List<Handle> matching(bool Function(Handle) predicate) {
    var matches = <Handle>[];

    for (var handle in _contents.values) {
      if (predicate(handle)) {
        matches.add(handle);
      }
    }

    return matches;
  }

  /// Branches the current scope off into another, and runs a block
  /// of code in the context of the new scope. Nothing can be added to
  /// or removed from the parent scope (although values may change).
  void branch(void Function(Scope) toRun) {
    var child = Scope(this);

    // Make current() return the child.
    stack.add(child);
    toRun(child);

    // We're leaving the scope, so remove the child.
    stack.removeLast();
  }

  void delete(String name) {
    if (!has(name)) {
      throw RuntimeError('Undeclared identifier "$name".');
    }

    _contents.remove(name);
  }
}
