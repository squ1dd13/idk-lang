import 'package:language/runtime/concrete.dart';

import 'exception.dart';
import 'handle.dart';

class Scope {
  final _contents = <String, Handle>{};
  final _deferred = <dynamic Function()>[];
  var _open = false;
  final Scope parent;

  static final _stack = <Scope>[Scope(null)];

  Scope(this.parent);

  static Scope current() => _stack.last;

  static Scope global() => _stack.first;

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
    child.enter();

    toRun(child);

    child.leave();
  }

  void delete(String name) {
    if (!has(name)) {
      throw RuntimeError('Undeclared identifier "$name".');
    }

    _contents.remove(name);
  }

  void defer(dynamic Function() action) {
    _deferred.add(action);
  }

  void enter() {
    if (_open) {
      throw InternalException('Cannot enter scope twice.');
    }

    _open = true;
    _stack.add(this);
  }

  void leave() {
    if (!_open) {
      throw InternalException('Attempted to leave closed scope!');
    }

    if (_stack.last != this) {
      throw InternalException('Cannot leave() non-last scope.');
    }

    for (var action in _deferred) {
      var returnValue = action();

      if (returnValue is SideEffect) {
        if (returnValue.isInterrupt) {
          if (returnValue.thrown != null) {
            throw RuntimeError(
                'Exception thrown on exiting scope: ${returnValue.thrown}.');
          }

          throw RuntimeError('Cannot modify control flow on scope exit!');
        }
      }
    }

    _open = false;
    _stack.removeLast();
  }
}
