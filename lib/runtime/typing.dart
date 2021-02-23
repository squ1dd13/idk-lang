import 'handle.dart';
import 'type.dart';

/// Manages value conversions between types.
class Conversion {
  // from type, <to type, conversion closure>
  static final _conversions =
      <ValueType, Map<ValueType, Handle Function(Handle)>>{};

  static void add(ValueType from, ValueType to, Handle Function(Handle) func) {
    if (!_conversions.containsKey(from)) {
      _conversions[from] = {to: func};

      return;
    }

    var existing = _conversions[from];

    if (existing.containsKey(to)) {
      throw Exception('Conversion from "$from" to "$to" already exists.');
    }

    existing[to] = func;
  }

  static Handle convertHandle(Handle from, ValueType to) {
    return _conversions[from.handleType][to](from);
  }

  static Handle convertValue(Handle from, ValueType to) {
    return _conversions[from.valueType][to](from);
  }
}
