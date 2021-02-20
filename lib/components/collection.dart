import 'package:language/components/util.dart';
import 'package:language/lexer.dart';
import 'package:language/runtime/concrete.dart';
import 'package:language/runtime/expression.dart';

import '../parser.dart';

/// A collection literal. These always use braces, so in order to
/// distinguish an empty map from an empty array or list, it is
/// written as `{:}` rather than the `{}` that may be used for
/// other collection types.
class CollectionLiteral implements Expressible {
  final _elementExpressions = <Expression>[];

  CollectionLiteral(TokenStream tokens) {
    tokens.requireNext('Expected braced list as collection literal.', 1,
        GroupPattern('{', '}'));

    var group = tokens.take();
    var allElementTokens = group.allTokens();

    var elementStream = TokenStream(allElementTokens, 0);

    // TODO: Maps
    const commaPattern = TokenPattern(string: ',', type: TokenType.Symbol);

    var elementGroups = Parse.split(elementStream, commaPattern);

    for (var elementGroup in elementGroups) {
      _elementExpressions.add(Parse.expression(elementGroup));
    }
  }

  @override
  Expression createExpression() {
    return InlineExpression(() {
      var list = InitializerList();

      for (var expression in _elementExpressions) {
        list.contents.add(expression.evaluate());
      }

      return list;
    });
  }
}
