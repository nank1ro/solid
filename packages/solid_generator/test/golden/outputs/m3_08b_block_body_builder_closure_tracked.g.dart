import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class BuilderProbe extends StatefulWidget {
  const BuilderProbe({super.key});

  @override
  State<BuilderProbe> createState() => _BuilderProbeState();
}

class _BuilderProbeState extends State<BuilderProbe> {
  final label = Signal<String>('', name: 'label');

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return SignalBuilder(
          builder: (context, child) {
            return Text(label.value);
          },
        );
      },
    );
  }
}
