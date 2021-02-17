import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';

import '../lexer.dart';

/// Something that can be converted to a statement.
abstract class Statable {
  Statement createStatement();
}

abstract class Expressible {
  Expression createExpression();
}

class InvalidSyntaxException extends FormatException {
  /// How far through the parsing the error was found.
  /// Used to determine which syntax error to show.
  final int stage;
  final int line;
  final int column;

  const InvalidSyntaxException(
      String message, this.stage, this.line, this.column)
      : super(message);

  @override
  String toString() => '($line, $column) $message';
}

class TokenStream {
  final _savedPositions = <int>[];
  int _index = 0;
  final List<Token> _collection;

  TokenStream(this._collection, this._index);

  void saveIndex() {
    _savedPositions.add(_index);
  }

  void restoreIndex() {
    _index = _savedPositions.last;
    _savedPositions.removeLast();
  }

  Token current() => _collection[_index];

  Token take() => _collection[_index++];

  void skip() => _index++;

  void requireNext(String message, int stage, TokenPattern pattern) {
    if (!hasCurrent() || pattern.notMatch(current())) {
      throw createException(message, stage);
    }
  }

  void requireNextNot(String message, int stage, TokenPattern pattern) {
    if (!hasCurrent() || pattern.hasMatch(current())) {
      throw createException(message, stage);
    }
  }

  bool hasCurrent() => _index < _collection.length;

  List<Token> takeWhile(bool Function(Token token) predicate) {
    var taken = <Token>[];

    while (hasCurrent() && predicate(current())) {
      taken.add(take());
    }

    return taken;
  }

  void skipWhile(bool Function(Token token) predicate) {
    while (hasCurrent() && predicate(current())) {
      skip();
    }
  }

  void consumeSemicolon(int stage, {String message = 'Expected semicolon.'}) {
    requireNext(message, stage, TokenPattern.semicolon);
    skip();
  }

  InvalidSyntaxException createException(String message, int stage) {
    return InvalidSyntaxException(
        message, stage, current().line, current().column);
  }

  List<Token> toList() {
    return _collection.sublist(_index);
  }
}

class TokenPattern {
  final String _stringMatch;
  final TokenType _typeMatch;

  const TokenPattern({String string, TokenType type})
      : _stringMatch = string,
        _typeMatch = type;

  const TokenPattern.type(this._typeMatch) : _stringMatch = null;

  const TokenPattern.string(this._stringMatch) : _typeMatch = null;

  bool hasMatch(Token token) {
    if (_stringMatch != null && token.toString() != _stringMatch) {
      return false;
    }

    if (_typeMatch != null && token.type != _typeMatch) {
      return false;
    }

    return true;
  }

  bool notMatch(Token token) => !hasMatch(token);

  static const semicolon = TokenPattern(string: ';', type: TokenType.Symbol);
}

class GroupPattern extends TokenPattern {
  final TokenPattern _open;
  final TokenPattern _close;

  GroupPattern(String start, String end)
      : _open = TokenPattern(string: start, type: TokenType.Symbol),
        _close = TokenPattern(string: end, type: TokenType.Symbol);

  @override
  bool hasMatch(Token token) {
    return token is GroupToken &&
        _open.hasMatch(token.children.first) &&
        _close.hasMatch(token.children.last);
  }

  @override
  bool notMatch(Token token) {
    if (!(token is GroupToken)) {
      return true;
    }

    var children = (token as GroupToken).children;
    return _open.notMatch(children.first) || _close.notMatch(children.last);
  }
}
