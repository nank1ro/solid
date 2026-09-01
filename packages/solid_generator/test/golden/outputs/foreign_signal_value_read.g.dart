import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class GateModel implements Disposable {
  GateModel(this.complete);

  final Signal<bool?> complete;

  late final ready = Computed<bool>(
    () => complete.value == true,
    name: 'ready',
  );

  late final calledReady = Computed<bool>(
    () => complete() == true,
    name: 'calledReady',
  );

  @override
  void dispose() {
    calledReady.dispose();
    ready.dispose();
  }
}

class GateBanner extends StatelessWidget {
  const GateBanner({required this.complete, super.key});

  final Signal<bool?> complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('gate'),
        SignalBuilder(
          builder: (context, child) {
            return Text('raw: ${complete.value}');
          },
        ),
      ],
    );
  }
}

class GateCall extends StatelessWidget {
  const GateCall({required this.complete, super.key});

  final Signal<bool?> complete;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('call: ${complete()}');
      },
    );
  }
}

class GateProbe extends StatelessWidget {
  const GateProbe({required this.complete, required this.resource, super.key});

  final Signal<bool?> complete;
  final Resource<bool?> resource;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('hadPrevious: ${complete.hasPreviousValue}');
          },
        ),
        SignalBuilder(
          builder: (context, child) {
            return Text('state: ${resource.state}');
          },
        ),
      ],
    );
  }
}

class GateOptOut extends StatelessWidget {
  const GateOptOut({required this.complete, super.key});

  final Signal<bool?> complete;

  @override
  Widget build(BuildContext context) {
    return Text('opt-out: ${complete.untracked.value}');
  }
}
