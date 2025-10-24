import 'package:build/build.dart';

import 'src/solid_builder.dart';

/// Factory function for creating the SolidBuilder.
/// This is called by build_runner when processing files.
Builder solidBuilder(BuilderOptions options) {
  print('DEBUG: solidBuilder factory called!');
  return SolidBuilder();
}
