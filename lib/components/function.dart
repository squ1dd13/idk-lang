import 'package:language/runtime/statements.dart';

import '../lexer.dart';
import '../parser.dart';
import '../runtime/concrete.dart';
import '../runtime/function.dart';
import '../runtime/scope.dart';
import 'typename.dart';
import 'util.dart';

class _Parameter {
  late TypeName type;
  String? name;

  _Parameter(TokenStream tokens) {
    type = TypeName(tokens);

    tokens.requireNext('Function parameters cannot be anonymous.', 2,
        TokenPattern.type(TokenType.Name));

    name = tokens.take().toString();
  }
}

class FunctionStatement extends Statement
    implements ClassChild, FunctionChild, LoopChild {
  late TypeName returnType;
  String? name;
  final parameters = <_Parameter>[];
  final body = <FunctionChild>[];
  var isOverride = false;

  FunctionStatement(bool isStatic) : super(isStatic);

  @override
  SideEffect execute() {
    // When the function declaration 'executes', it just means we need to
    //  add the variable to the current scope.

    var function = FunctionValue(name, returnType.evaluate(), body, isOverride);

    // Add the parameters.
    for (var parameter in parameters) {
      function.addParameter(parameter.name, parameter.type.evaluate());
    }

    function.applyType();
    Scope.current().add(name, function.createHandle());

    return SideEffect.nothing();
  }
}

class FunctionDeclaration implements Statable {
  FunctionStatement? _statement;

  FunctionDeclaration(TokenStream tokens) {
    _statement = FunctionStatement(Parse.staticKeyword(tokens));
    tokens.requireNext('Functions must declare a return type.', 1,
        TokenPattern.type(TokenType.Name));

    _statement!.returnType = TypeName(tokens);

    tokens.requireNext(
        'Function must have a name.', 2, TokenPattern.type(TokenType.Name));

    _statement!.name = tokens.take().toString();

    // An exclamation mark ("!") after the function name means that it overrides
    //  a method in a parent class.
    const overridePattern = TokenPattern(string: '!', type: TokenType.Symbol);

    if (overridePattern.hasMatch(tokens.current())) {
      _statement!.isOverride = true;
      tokens.skip();
    }

    tokens.requireNext('Expected parameter list.', 3, GroupPattern('(', ')'));

    var parameterGroup = tokens.take() as GroupToken;

    // Create a token stream for the group without the delimiters (middle()).
    var parameterStream = parameterGroup.contents();

    // Split by the comma symbol.
    var segments = Parse.split(
        parameterStream, TokenPattern(string: ',', type: TokenType.Symbol));

    // Parse all of the parameters.
    for (var segment in segments) {
      // Create a _Parameter from each segment's tokens.
      _statement!.parameters.add(_Parameter(TokenStream(segment, 0)));
    }

    tokens.requireNext('Expected function body after parameter list.', 4,
        GroupPattern('{', '}'));

    var bodyTokens = tokens.take() as GroupToken;
    _statement!.body
        .addAll(Parse.statements<FunctionChild>(bodyTokens.middle()));
  }

  @override
  Statement? createStatement() {
    return _statement;
  }
}
