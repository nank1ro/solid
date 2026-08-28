// Cross-instance `<receiver>.<queryName>.previousReady` / `.previousError` —
// the tear-off counterpart proving BOTH new retained-state getters (not just
// `previousState`) drive `SignalBuilder` placement + the `flutter_solidart`
// import through the cross-instance `classQueryNames` registry, when the
// consumer's `build()` reads ONLY the tear-offs (no `viewModel.customers()`
// call anywhere).
//
// Deliberately does NOT import `solid_annotations` (probe-path exercise, see
// the sibling `..._previous_state` fixture), so the `.value`/`.error`/
// `previousReady`/`previousError` source-time stubs are unavailable here; the
// resulting `undefined_getter` diagnostics are expected and silenced.
// ignore_for_file: undefined_getter

import 'package:flutter/widgets.dart';

import 'view_model.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen(this.viewModel, {super.key});

  final CustomersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${viewModel.customers.previousReady?.value.length ?? 0} '
      '${viewModel.customers.previousError?.error}',
    );
  }
}
