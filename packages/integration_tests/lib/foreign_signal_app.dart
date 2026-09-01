import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';

class Gate {
  /// Tri-state: `null` means "not known yet".
  final Signal<bool?> complete = Signal(null);

  // `complete` is hand-written, so the generator synthesizes no disposal for
  // it — the owner disposes it, and the provider scope's `dispose:` callback
  // calls through to here.
  void dispose() => complete.dispose();
}

class GateView extends StatefulWidget {
  const GateView({super.key});

  @override
  State<GateView> createState() => _GateViewState();
}

class _GateViewState extends State<GateView> {
  late final gate = context.read<Gate>();
  late final ready = Computed<bool>(
    () => gate.complete.value ?? false,
    name: 'ready',
  );

  @override
  void dispose() {
    ready.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('raw: ${gate.complete.value}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('ready: ${ready.value}');
          },
        ),
      ],
    );
  }
}
