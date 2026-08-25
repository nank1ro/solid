// Negative case for the instance-field cross-class resolution tier: a
// constructor-injected field whose declared type has no `@SolidState`
// member at all. The rewriter must leave `_helper.count` completely
// unchanged — proves the new AST fallback resolves the receiver's type
// (`PlainHelper`) but still no-ops because `PlainHelper` never enters the
// cross-class registry (it carries no reactive annotations).

import 'package:solid_annotations/solid_annotations.dart';

class PlainHelper {
  int count = 0;
}

class Reporter {
  Reporter(this._helper);

  final PlainHelper _helper;

  @SolidState()
  int calls = 0;

  int report() {
    calls = calls + 1;
    return _helper.count;
  }
}
