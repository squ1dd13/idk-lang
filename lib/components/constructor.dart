import 'package:language/lexer.dart';
import 'package:language/parser.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/exception.dart';
import 'package:language/runtime/expression.dart';
import 'package:language/runtime/function.dart';
import 'package:language/runtime/object.dart';
import 'package:language/runtime/scope.dart';
import 'package:language/runtime/statements.dart';

import 'typename.dart';
import 'util.dart';

/// Constructor parameters can be "self.x" or "super.x" to allow simple
/// constructors that just directly set members, or they can be more like
/// function parameters (just named values which are set when the constructor
/// is called).
class _ConstructorParameter {
  Expression valueExpression;
  TypeName type;
  String name;

  _ConstructorParameter(TokenStream tokens) {
    const comma = TokenPattern(string: ',', type: TokenType.Symbol);

    var parameterTokens = tokens.takeWhile(comma.notMatch);

    // If there's anything left in the stream, skip it (because it will be a
    //  comma).
    if (tokens.hasCurrent()) {
      tokens.skip();
    }

    if (parameterTokens.first.type == TokenType.Name) {
      var string = parameterTokens.first.toString();

      if (string == 'self' || string == 'super') {
        valueExpression = Parse.expression(parameterTokens);
        return;
      }
    }

    var parameterStream = TokenStream(parameterTokens, 0);
    type = TypeName(parameterStream);

    parameterStream.requireNext('Function parameters cannot be anonymous.', 20,
        TokenPattern.type(TokenType.Name));

    name = parameterStream.take().toString();
  }
}

class ConstructorStatement extends StaticStatement implements ClassChild {
  String name;
  var parameters = <_ConstructorParameter>[];
  final body = <FunctionChild>[];

  @override
  SideEffect execute() {
    var classType = ClassType.classTypeStack.last;

    var function = FunctionValue.implemented(parameters.length, (arguments) {
      var createdObject = ClassObject(classType);

      var returnEffect = SideEffect.nothing();
      createdObject.scope.branch((constructorLocal) {
        for (var i = 0; i < parameters.length; ++i) {
          if (parameters[i].valueExpression != null) {
            // "super.x" or "self.x" to assign to here.
            var assignmentHandle = parameters[i].valueExpression.evaluate();
            assignmentHandle.value = arguments[i].value;
          } else {
            constructorLocal.add(parameters[i].name, arguments[i]);
          }
        }

        // Handle returnHandle;

        for (var statement in body) {
          var result = FunctionValue.runStatement(statement);

          if (result.isInterrupt) {
            returnEffect = result;
            break;
          }
        }

        if (returnEffect.returned != null) {
          throw RuntimeError('Constructors may not return values.');
        }
      });

      if (returnEffect.thrown != null) {
        return returnEffect;
      }

      return SideEffect.returns(createdObject.createHandle());
    });

    // Register the constructor with the class.
    Scope.current().add(name, function.createHandle());

    return SideEffect.nothing();
  }
}

/// A constructor declaration.
class ConstructorDeclaration implements Statable {
  final _statement = ConstructorStatement();

  ConstructorDeclaration(TokenStream tokens, {bool anonymous = false}) {
    tokens.requireNext('Constructor must start with "new".', 1,
        TokenPattern(string: 'new', type: TokenType.Name));

    // "new"
    tokens.skip();

    if (!anonymous) {
      // Stage 10 because if we found 'new' it's very likely to be an attempt
      //  at declaring a constructor.
      tokens.requireNext('Constructors may not be anonymous.', 10,
          TokenPattern.type(TokenType.Name));
      _statement.name = tokens.take().toString();
    } else {
      _statement.name = '';
    }

    tokens.requireNext('Expected "()" in constructor declaration.', 11,
        GroupPattern('(', ')'));

    var parameterStream = TokenStream(tokens.take().allTokens(), 0);

    // Read parameters until there are no tokens left.
    while (parameterStream.hasCurrent()) {
      _statement.parameters.add(_ConstructorParameter(parameterStream));
    }

    var bodyToken = tokens.take();
    var bracesPattern = GroupPattern('{', '}');

    if (bracesPattern.hasMatch(bodyToken)) {
      _statement.body.addAll(Parse.statements(bodyToken.allTokens()));
    } else if (!TokenPattern.semicolon.hasMatch(bodyToken)) {
      // A semicolon is fine, because it means there is no constructor body.
      // If there is no semicolon or braces, there's something off.
      bodyToken.throwSyntax(
          'Expected "{}" or ";" after constructor parameters.', 12);
    }
  }

  @override
  Statement createStatement() {
    return _statement;
  }
}
