// Rejection suite for same-package `package:<self>/...` imports in source
// files. Source must stay inside the source/ realm — `package:` URIs route
// through `lib/`, which is the wrong target for an authored file. See SPEC §2.

import '../integration/golden_helpers.dart';

const List<({String name, String errorContains})> _cases = [
  (
    name: 'source_self_package_import_rejected',
    errorContains: 'Source-side same-package `package:` import is not allowed',
  ),
];

void main() {
  runRejectionCases('source-side same-package import is rejected', _cases);
}
