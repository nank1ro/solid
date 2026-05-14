import 'package:flutter/material.dart';

class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.code, this.size = 32});

  final int code;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(_iconFor(code), size: size, color: _colorFor(code));
  }

  static IconData _iconFor(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code == 1 || code == 2) return Icons.wb_cloudy;
    if (code == 3) return Icons.cloud;
    if (code == 45 || code == 48) return Icons.blur_on;
    if (code >= 51 && code <= 57) return Icons.grain;
    if (code >= 61 && code <= 67) return Icons.umbrella;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.beach_access;
    if (code >= 85 && code <= 86) return Icons.ac_unit;
    if (code >= 95) return Icons.flash_on;
    return Icons.help_outline;
  }

  static Color _colorFor(int code) {
    if (code == 0) return Colors.orange;
    if (code >= 95) return Colors.deepPurple;
    if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
      return Colors.lightBlue;
    }
    if (code >= 61 && code <= 67 || code >= 80 && code <= 82) {
      return Colors.blue;
    }
    return Colors.blueGrey;
  }
}
