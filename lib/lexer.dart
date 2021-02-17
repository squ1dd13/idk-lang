import 'dart:math';

import 'parser/operation.dart' as operation;
import 'parser/util.dart';

enum TokenType { Name, Symbol, Number, String, Keyword, Group, None }

abstract class Token {
  TokenType type = TokenType.None;
  int line, column;

  Token();

  Token.ofType(this.type);

  /// All subtokens of this token.
  List<Token> allTokens() {
    return [this];
  }
}

class TextToken extends Token {
  final String _text;

  TextToken(TokenType tokenType, this._text) {
    super.type = tokenType;
  }

  @override
  String toString() {
    return _text;
  }
}

class GroupToken extends Token {
  final List<Token> children;

  GroupToken(this.children);

  @override
  List<Token> allTokens() {
    return middle();
  }

  List<Token> middle() {
    return children.sublist(1, children.length - 1);
  }

  TokenStream contents() {
    return TokenStream(middle(), 0);
  }

  bool delimitedBy(TokenPattern open, TokenPattern close) {
    return children.length >= 2 &&
        open.hasMatch(children.first) &&
        close.hasMatch(children.last);
  }
}

const _whitespace = ' \t\n\r';
const _symbols = '@<>[]{}()+=/?-#~:;|!\$%^&*';

class Lexer {
  var generatedTokens = <Token>[];

  final String _text;
  int _position = -1;

  /// Create a new Lexer and lex [type].
  Lexer(this._text) {
    // Generate a bunch of separate tokens.
    while (_moveNext()) {
      var startPos = _position;

      // Try generating a string literal.
      if (_generateStringLiteral()) {
        continue;
      }

      _position = startPos;

      if (_generateName()) {
        continue;
      }

      _position = startPos;

      if (_generateOperator()) {
        continue;
      }

      _position = startPos;

      if (_generateIntLiteral()) {
        continue;
      }

      _position = startPos;

      var character = _getCharacter();

      if (_whitespace.contains(character)) {
        continue;
      }

      if (_symbols.contains(character)) {
        _addToken(TextToken(TokenType.Symbol, character));
        continue;
      }
    }

    _fixWordOperators();
    _createGroups();
  }

  /// Convert word operators like "and", "or" and "xor" into symbols.
  void _fixWordOperators() {
    for (var i = 0; i < generatedTokens.length; ++i) {
      var token = generatedTokens[i];

      if (token.type == TokenType.Name &&
          operation.operators.containsKey(token.toString())) {
        generatedTokens[i] = TextToken(TokenType.Symbol, token.toString());
      }
    }
  }

  void _addToken(Token token) {
    var lineColumn = _lineAndColumn();
    token.line = lineColumn[0];
    token.column = lineColumn[1];

    generatedTokens.add(token);
  }

  bool _hasNext() => _position < _text.length;

  bool _moveNext() => ++_position < _text.length;

  List<int> _lineAndColumn() {
    var line = 1, column = 1;
    var smaller = min(_text.length, _position);

    for (var i = 0; i < smaller; ++i) {
      if (_text[i] == '\n') {
        ++line;
        column = 1;
      } else {
        ++column;
      }
    }

    return [line, column];
  }

  static final _opChars = <String>{};

  static Set<String> get _operatorChars {
    if (_opChars.isEmpty) {
      for (var operator in operation.operators.keys) {
        _opChars.addAll(
            operator.codeUnits.map((code) => String.fromCharCode(code)));
      }
    }

    return _opChars;
  }

  bool _generateOperator() {
    // TODO: Improve operator lexing (make it work properly).

    var buffer = StringBuffer();
    var startLineColumn = _lineAndColumn();

    while (_hasNext() && _operatorChars.contains(_getCharacter())) {
      buffer.write(_getCharacter(moveAfter: true));
    }

    if (buffer.isEmpty) {
      return false;
    }

    var operatorString = buffer.toString();

    if (!operation.operators.containsKey(operatorString)) {
      // Split into multiple tokens.
      for (var i = 0; i < operatorString.length; ++i) {
        var character = String.fromCharCode(operatorString.codeUnitAt(i));

        var token = TextToken(TokenType.Symbol, character);
        token.line = startLineColumn[0];

        // We only need to add to the column because we know the line won't
        //  have changed: you can't have a newline character in an operator.
        token.column = startLineColumn[1] + i;

        generatedTokens.add(token);
      }
    } else {
      if (_hasNext()) {
        // Go back so we can process the last character on the next lexing
        //  pass.
        --_position;
      }

      _addToken(TextToken(TokenType.Symbol, operatorString));
    }

    return true;
  }

  /// Attempt to read an identifier.
  bool _generateName() {
    bool isValidInName(String character) {
      const valid = '_01234567890abcdefghijklmnopqrstuvwxyz';
      return valid.contains(character.toLowerCase());
    }

    var buffer = StringBuffer();
    var endedOnInvalid = false;

    // do...while because we don't want to moveNext before reading.
    do {
      var character = _getCharacter();

      if (!isValidInName(character)) {
        endedOnInvalid = true;
        break;
      }

      buffer.write(character);
    } while (_moveNext());

    // Bail if we couldn't create an identifier (because there wasn't even
    //  a single valid character).
    if (buffer.isEmpty) {
      return false;
    }

    // -1 from the index so the invalid character gets processed.
    if (endedOnInvalid) {
      --_position;
    }

    var name = buffer.toString();
    if (!RegExp('[_a-zA-Z][_a-zA-Z0-9]*').hasMatch(name)) {
      return false;
    }

    _addToken(TextToken(TokenType.Name, name));

    return true;
  }

  bool _generateIntLiteral() {
    bool isDigit(String char) => (char.codeUnitAt(0) ^ 0x30) <= 9;

    var buffer = StringBuffer();
    var foundEnd = false;

    while (isDigit(_getCharacter())) {
      buffer.write(_getCharacter());

      if (!_moveNext()) {
        foundEnd = true;
        break;
      }
    }

    if (!foundEnd) {
      --_position;
    }

    if (buffer.isEmpty) {
      return false;
    }

    _addToken(TextToken(TokenType.Number, buffer.toString()));
    return true;
  }

  /// Attempt to read a string literal.
  bool _generateStringLiteral() {
    // Requires "quotes".
    if (_getCharacter() != '"') {
      return false;
    }

    var buffer = StringBuffer();

    var escaped = false;
    while (_moveNext()) {
      var character = _getCharacter();

      if (!escaped) {
        if (character == '"') {
          // Closing quote.
          break;
        }

        if (character == '\\') {
          escaped = true;
        } else {
          buffer.write(character);
        }

        continue;
      }

      // TODO: Handle more escaped characters.
      const escapedCharacters = {'\\': '\\', 'n': '\n'};

      if (escapedCharacters.containsKey(character)) {
        // Write the escaped character's replacement.
        buffer.write(escapedCharacters[character]);
      } else {
        // Just write the character.
        buffer.write(character);
      }

      escaped = false;
    }

    _addToken(TextToken(TokenType.String, buffer.toString()));
    return true;
  }

  String _getCharacter({bool moveAfter = false}) {
    void advance() {
      if (moveAfter) {
        _moveNext();
      }
    }

    try {
      var char = _text[_position];
      advance();
      return char;
    } catch (exception) {
      advance();
      return '';
    }
  }

  /// Find tokens between common delimiters and group them.
  void _createGroups() {
    var tokens = generatedTokens;

    const openingSymbols = <String>{
      '{',
      '(',
      '[' /*, "<"*/
    };
    const allDelimiters = <String>{
      '{',
      '(',
      '[',
      /* "<", */
      '}',
      ')',
      ']' /*, ">"*/
    };

    const reverseSymbols = <String, String>{
      '{': '}',
      '(': ')',
      '[': ']',
      /* { "<", ">" }, */
    };

    var groups = <GroupToken>[GroupToken([])];

    var delimiters = <String>[];

    for (var tokenGroup in tokens) {
      if (tokenGroup.type != TokenType.Symbol ||
          !allDelimiters.contains(tokenGroup.toString())) {
        groups.last.children.add(tokenGroup);
        continue;
      }

      if (openingSymbols.contains(tokenGroup.toString())) {
        groups.last.children.add(GroupToken([]));
        groups.add(groups.last.children.last);
        groups.last.children.add(tokenGroup);

        delimiters.add(tokenGroup.toString());
      } else if (delimiters.isNotEmpty &&
          tokenGroup.toString() == reverseSymbols[delimiters.last]) {
        groups.last.children.add(tokenGroup);

        delimiters.removeLast();
        groups.removeLast();
      } else {
        var lineColumn = _lineAndColumn();
        throw InvalidSyntaxException(
            'Mismatched delimiters.', 1, lineColumn[0], lineColumn[1]);
      }
    }

    generatedTokens = groups.last.children;

    for (var token in generatedTokens) {
      if (token is GroupToken && token.children.isNotEmpty) {
        token.line = token.children[0].line;
        token.column = token.children[0].column;
      }
    }
  }
}
