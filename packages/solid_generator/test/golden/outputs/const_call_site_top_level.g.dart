import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

void main() => runApp(const Outer(child: Inner()));

class Inner extends StatefulWidget {
  const Inner({super.key});

  @override
  State<Inner> createState() => _InnerState();
}

class _InnerState extends State<Inner> {
  final n = Signal<int>(0, name: 'n');

  @override
  void dispose() {
    n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('${n.value}');
      },
    );
  }
}

class Outer extends StatefulWidget {
  const Outer({super.key, required this.child});

  final Widget child;

  @override
  State<Outer> createState() => _OuterState();
}

class _OuterState extends State<Outer> {
  final m = Signal<int>(0, name: 'm');

  @override
  void dispose() {
    m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SignalBuilder(
          builder: (context, child) {
            return Text('${m.value}');
          },
        ),
        widget.child,
        const Inner(),
      ],
    );
  }
}
