import 'dart:math';

import 'parser/operation.dart' as operation;
import 'parser/util.dart';

enum TokenType { Name, Symbol, Number, String, Group, None }

abstract class Token {
  TokenType type = TokenType.None;
  int line, column;

  Token();

  Token.ofType(this.type);

  /// All subtokens of this token.
  List<Token> allTokens() {
    return [this];
  }

  bool get isOperator {
    return type == TokenType.Symbol &&
        operation.operators.containsKey(toString());
  }

  bool get isNotOperator {
    return type != TokenType.Symbol ||
        !operation.operators.containsKey(toString());
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
const _symbols = ',@<>[]{}()+=/?-#~:;|!\$%^&*';

class Lexer {
  var generatedTokens = <Token>[];

  final String _text;
  int _position = -1;

  /// Create a new Lexer and lex [type].
  Lexer(this._text) {
    // Generate a bunch of separate tokens.
    while (_moveNext()) {
      var startPos = _position;

      if (_generateOperator()) {
        continue;
      }

      _position = startPos;

      // Try generating a string literal.
      if (_generateStringLiteral()) {
        continue;
      }

      _position = startPos;

      if (_generateName()) {
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

      var lineColumn = _lineAndColumn();
      throw InvalidSyntaxException('Unexpected character "$character".', 0,
          lineColumn[0], lineColumn[1]);
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

  static Set<String> _operatorStarters;

  bool _generateOperator() {
    // Fill operatorStarters on the first call so only the operators set has to be
    //  updated to add an operator.
    if (_operatorStarters == null) {
      _operatorStarters = <String>{};
      for (var key in operation.operators.keys) {
        _operatorStarters.add(key.substring(0, 1));
      }
    }

    if (!_operatorStarters.contains(_getCharacter())) return false;

    var operatorString = '';

    // Keep reading until the next character invalidates the operator.
    while (true) {
      var extendedOperator = operatorString + _getCharacter();

      var foundAny =
          operation.operators.keys.any((k) => k.startsWith(extendedOperator));

      if (!foundAny) {
        const identifierChars = '_abcdefghijklmnopqrstuvwxyz0123456789';
        const alphabet = 'abcdefghijklmnopqrstuvwxyz';

        // This is why you cannot mix letters and symbols in operators: we need to
        //  know whether this is operator "xy" or the start of the word "xyz".
        // If we find the 'z', we know it is part of the same word because it comes
        //  after a 'y', which is alphabetical.
        var lastChar = operatorString[operatorString.length - 1];

        if (identifierChars.contains(_getCharacter().toLowerCase()) &&
            alphabet.contains(lastChar.toLowerCase())) {
          // We've discovered that this 'operator' is actually the start of a word,
          //  so set the operator string to empty and cancel.
          operatorString = '';
        }

        // Operator invalidated by the new character, so stop here.
        break;
      }

      operatorString = extendedOperator;
      _moveNext();
    }

    // The final character (the one that invalidated the operator) doesn't
    //  belong to us, so go back to it so the next lexing pass can read it.
    --_position;

    if (operatorString.isEmpty ||
        !operation.operators.containsKey(operatorString)) {
      return false;
    }

    _addToken(TextToken(TokenType.Symbol, operatorString));
    return true;
  }

  bool _genedrateOperator() {
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
    const delimiters = <String, String>{
      '{': '}',
      '(': ')',
      '[': ']',
    };

    // Our token groups. We start with one empty group for top-level tokens.
    var tokenGroups = <List<Token>>[[]];

    for (var token in generatedTokens) {
      if (token.type != TokenType.Symbol) {
        // Non-symbols are useless.
        tokenGroups.last.add(token);
        continue;
      }

      var tokenValue = token.toString();

      var isOpening = delimiters.keys.contains(tokenValue);
      var isClosing = !isOpening && delimiters.values.contains(tokenValue);

      if (!isOpening && !isClosing) {
        // This is just a normal symbol, so add it like any other token.
        tokenGroups.last.add(token);
        continue;
      }

      // Is this an opening delimiter?
      if (isOpening) {
        // Yes, so start a new group with it. This group won't close
        //  until we find a closing delimiter at the same level as the
        //  opening one.
        tokenGroups.add([token]);
        continue;
      }

      // Is this a closing delimiter?
      if (isClosing) {
        // Yes, so make sure it matches the current group's opening
        //  delimiter. If it does, we can add the closing token and
        //  close the group.

        // You can't close the global group.
        if (tokenGroups.length == 1) {
          throw InvalidSyntaxException(
              'Cannot close global scope!', 0, token.line, token.column);
        }

        // The first token of the group is guaranteed to be a delimiter.
        var openingToken = tokenGroups.last.first;
        var openingDelimiter = openingToken.toString();

        // Make sure the delimiters match.
        var expectedDelimiter = delimiters[openingDelimiter];

        if (tokenValue != expectedDelimiter) {
          throw InvalidSyntaxException(
              'Expected "$expectedDelimiter" to match "$openingDelimiter" '
              '(${openingToken.line}, ${openingToken.column}).',
              0,
              token.line,
              token.column);
        }

        tokenGroups.last.add(token);

        // The group is now closed, so we can turn it into a token and
        //  add it to its parent group.
        var closedTokens = tokenGroups.removeLast();

        // The last group is now the parent.
        tokenGroups.last.add(GroupToken(closedTokens));
      }
    }

    // All the closed groups should now be in the global group.
    // If there is anything else left, something wasn't closed properly.
    if (tokenGroups.length > 1) {
      var errorStart = tokenGroups[1].first;
      throw InvalidSyntaxException(
          'Unterminated group.', 0, errorStart.line, errorStart.column);
    }

    // Replace the ungrouped tokens with the grouped ones from the global
    //  group.
    generatedTokens = tokenGroups[0];
  }
}
