import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/function.dart';
import 'package:language/runtime/object.dart';
import 'package:language/runtime/store.dart';
import 'package:language/runtime/type.dart';

import 'util.dart';

class ClassDeclaration implements Statable {
  Expression _superclassExpression;
  String _name;
  List<Statement> _body;

  ClassDeclaration(TokenStream tokens) {
    tokens.requireNext('Expected "class".', 1,
        TokenPattern(string: 'class', type: TokenType.Name));

    tokens.skip();

    tokens.requireNext('Expected class name after "class" keyword.', 2,
        TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();

    const ofPattern = TokenPattern(string: 'of', type: TokenType.Name);
    var bracePattern = GroupPattern('{', '}');

    if (ofPattern.hasMatch(tokens.current())) {
      // Skip the 'of'.
      tokens.skip();

      var untilBraces = tokens.takeWhile(bracePattern.notMatch);
      _superclassExpression = Parse.expression(untilBraces);
    }

    tokens.requireNext(
        'Expected braces after class or superclass name.', 3, bracePattern);

    _body = Parse.statements(tokens.take().allTokens());
  }

  ValueType _classType() {
    var type = ClassType(_name, _body, _superclassExpression?.evaluate());

    if (!Store.current().has(_name)) {
      Store.current().add(_name, type.createConstant());
    } else {
      return Store.current().get(_name).value;
    }

    return type;
  }

  /// Create a constructor function. This is only needed until we have real
  /// constructors.
  FunctionValue _generateConstructor() {
    return FunctionValue.implemented(0, (arguments) {
      var created = ClassObject(_classType()).createHandle();
      return SideEffect.returns(created);
    }, named: 'New_$_name', returns: _classType());
  }

  @override
  Statement createStatement() {
    return SideEffectStatement(() {
      var constructor = _generateConstructor();
      Store.current().add(constructor.name, constructor.createHandle());

      // Register all the components inside a branch.
      // Store.current().branch((store) {
      //   // TODO: Give stores a 'staticStore' friend for statics.
      //   // The static store here would be for the class' type object.
      //
      //   for (var statement in _body) {
      //     statement.execute();
      //   }
      // });

      return null;
    });
  }
}
