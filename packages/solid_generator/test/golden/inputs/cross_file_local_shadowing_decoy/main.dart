// BLOCKER regression fixture (issue #104 fix review, finding 1): this file
// declares its OWN plain `class Address` (zero `@SolidState` members) and
// holds an instance of it as a constructor-injected field on `Shipping`,
// while ALSO importing an unrelated file that happens to declare a
// DIFFERENT, `@SolidState`-annotated `class Address`.
//
// Dart's name-resolution rule — a top-level declaration in the current
// library always shadows a same-name imported declaration, with no error —
// means `Address` inside this file unambiguously refers to the LOCAL plain
// class. `Shipping.address.line1` must stay untouched by the reactive
// rewrite.
//
// Before the fix: `_populateCrossFileTypes` seeded `wantedTypes` with
// `Address` purely from `Shipping`'s constructor-parameter declared type
// name, then the cross-file import walk (blind to local shadowing) matched
// `remote_address.dart`'s reactive `Address.line1` to that name and
// populated `classRegistry['Address']`, producing a non-compiling
// `address.line1.value` rewrite against the local plain field.
// ignore_for_file: unused_import

import 'package:solid_annotations/solid_annotations.dart';

import 'remote_address.dart';

class Address {
  Address(this.line1);

  final String line1;
}

class Shipping {
  Shipping(this.address);

  final Address address;

  @SolidState()
  int loadCount = 0;

  String describe() {
    loadCount = loadCount + 1;
    return address.line1;
  }
}
