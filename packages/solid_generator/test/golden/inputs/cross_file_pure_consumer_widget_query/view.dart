// Pure-consumer `StatelessWidget`: no `@Solid*` annotation of its own, reads
// a cross-file `@SolidQuery` method through a plain constructor-injected
// `viewModel` field. See `view_model.dart` for why this exercises the fix
// in isolation from the (already-working) cross-instance `@SolidState`
// path — `CustomersViewModel` has no `@SolidState` member at all, so
// `classRegistry` stays empty for this file; only the new `classQueryNames`
// registry has anything to offer.
//
// Deliberately does NOT import `solid_annotations` (unlike every annotated
// query fixture) — that import's URI text would flip `builder.dart`'s
// `hasSolidAnnotation` hint true and route this file through the main
// annotated-class path instead of the fast no-annotation PROBE path (see
// `build()`'s `probeQueryNames` short-circuit). This fixture exists
// specifically to exercise that probe path for a pure-query consumer, so
// the `.isLoading`/`.asError`/`.asReady`/`.refresh` source-time stub
// extensions (normally provided by `solid_annotations`) are unavailable
// here; the resulting `undefined_getter`/`undefined_method` diagnostics are
// expected and silenced below rather than worked around.
// ignore_for_file: undefined_getter, undefined_method

import 'package:flutter/widgets.dart';

import 'view_model.dart';

// A plain, unrelated widget receiving the read values. Field types are
// ordinary Dart/Flutter types so this class itself needs no stub extension
// to typecheck.
class CustomersList extends StatelessWidget {
  const CustomersList({
    required this.isLoading,
    required this.error,
    required this.totalCount,
    required this.onRetry,
    super.key,
  });

  final bool isLoading;
  final Object? error;
  final int totalCount;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class CustomersScreen extends StatelessWidget {
  const CustomersScreen(this.viewModel, {super.key});

  final CustomersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return CustomersList(
      isLoading: viewModel.customers().isLoading,
      error: viewModel.customers().asError?.error,
      totalCount: viewModel.customers().asReady?.value.length ?? 0,
      onRetry: viewModel.customers.refresh,
    );
  }
}
