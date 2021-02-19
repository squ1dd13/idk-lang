import '../lexer.dart';
import '../parser.dart';
import '../runtime/concrete.dart';
import '../runtime/expression.dart';
import '../runtime/function.dart';
import '../runtime/store.dart';
import 'typename.dart';
import 'util.dart';

class _Parameter {
  TypeName type;
  String name;

  _Parameter(TokenStream tokens) {
    type = TypeName(tokens);

    tokens.requireNext('Function parameters cannot be anonymous.', 2,
        TokenPattern.type(TokenType.Name));

    name = tokens.take().toString();
  }
}

class FunctionDeclaration implements Statable {
  // Stays as a TypeName until the declaration is evaluated - this lazy
  //  loading of types allows the type to be declared after it's first used.
  TypeName _returnType;
  String _name;
  final _parameters = <_Parameter>[];
  final _body = <Statement>[];

  FunctionDeclaration(TokenStream tokens) {
    // This will likely change in the future.
    tokens.requireNext('Functions must declare a return type.', 1,
        TokenPattern.type(TokenType.Name));

    _returnType = TypeName(tokens);

    tokens.requireNext(
        'Function must have a name.', 2, TokenPattern.type(TokenType.Name));

    _name = tokens.take().toString();

    // This /will/ change in the future.
    tokens.requireNext('Expected parameter list after function name.', 3,
        GroupPattern('(', ')'));

    var parameterGroup = tokens.take() as GroupToken;

    // Create a token stream for the group without the delimiters (middle()).
    var parameterStream = parameterGroup.contents();

    // Split by the comma symbol.
    var segments = Parse.split(
        parameterStream, TokenPattern(string: ',', type: TokenType.Symbol));

    // Parse all of the parameters.
    for (var segment in segments) {
      // Create a _Parameter from each segment's tokens.
      _parameters.add(_Parameter(TokenStream(segment, 0)));
    }

    tokens.requireNext('Expected function body after parameter list.', 4,
        GroupPattern('{', '}'));

    var bodyTokens = tokens.take() as GroupToken;
    _body.addAll(Parse.statements(bodyTokens.middle()));
  }

  @override
  Statement createStatement() {
    // When the function declaration 'executes', it just means we need to
    //  add the variable to the current store.
    return Statement(InlineExpression(() {
      var function = FunctionValue(_name, _returnType.evaluate(), _body);

      // Add the parameters.
      for (var parameter in _parameters) {
        function.addParameter(parameter.name, parameter.type.evaluate());
      }

      function.applyType();
      Store.current().add(_name, function);

      return null;
    }));
  }
}
