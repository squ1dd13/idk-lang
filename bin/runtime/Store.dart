import 'Concepts.dart';

class Store {
  final _contents = <String, Evaluable>{};

  static var stack = <Store>[Store()];
  static Store current() => stack.last;

  void add(String name, Evaluable item) {
    if (has(name)) {
      throw Exception('$name already exists in this scope.');
    }

    _contents[name] = item;
  }

  Evaluable get(String name) {
    if (!has(name)) {
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
    if (!has(name)) {
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
}