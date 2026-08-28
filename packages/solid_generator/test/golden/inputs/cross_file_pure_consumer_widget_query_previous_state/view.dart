// Cross-instance `<receiver>.<queryName>.previousState` — the tear-off
// counterpart of `cross_file_pure_consumer_widget_query`'s call-form test.
// `CustomersScreen.build()` reads ONLY `viewModel.customers.previousState`
// (no `viewModel.customers()` call anywhere), proving the tear-off form
// alone drives `SignalBuilder` placement + the `flutter_solidart` import
// through the cross-instance `classQueryNames` registry.
//
// Deliberately does NOT import `solid_annotations` — see
// `cross_file_pure_consumer_widget_query/view.dart`'s comment for why (the
// probe-path exercise). The `.asReady` source-time stub extension is
// therefore unavailable here; the resulting `undefined_getter` diagnostic
// is expected and silenced below rather than worked around.
// ignore_for_file: undefined_getter

import 'package:flutter/widgets.dart';

import 'view_model.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen(this.viewModel, {super.key});

  final CustomersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${viewModel.customers.previousState?.asReady?.value.length ?? 0}',
    );
  }
}
