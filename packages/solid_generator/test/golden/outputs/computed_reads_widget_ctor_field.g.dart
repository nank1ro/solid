import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class TempBadge extends StatefulWidget {
  const TempBadge({super.key, required this.label});

  final String label;

  @override
  State<TempBadge> createState() => _TempBadgeState();
}

class _TempBadgeState extends State<TempBadge> {
  final celsius = Signal<double>(0, name: 'celsius');
  late final display = Computed<String>(
    () => '${widget.label} ${celsius.value.toStringAsFixed(1)}',
    name: 'display',
  );

  @override
  void dispose() {
    display.dispose();
    celsius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context, child) {
      return Text(display.value);
    },
  );
}
