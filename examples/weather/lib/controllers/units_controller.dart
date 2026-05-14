import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import '../domain/units.dart';

class UnitsController implements Disposable {
  final tempUnit = Signal<TempUnit>(TempUnit.celsius, name: 'tempUnit');

  final windUnit = Signal<WindUnit>(WindUnit.kmh, name: 'windUnit');

  void setTempUnit(TempUnit unit) => tempUnit.value = unit;

  void setWindUnit(WindUnit unit) => windUnit.value = unit;

  void toggleTempUnit() => tempUnit.value = tempUnit.value == TempUnit.celsius
      ? TempUnit.fahrenheit
      : TempUnit.celsius;

  void toggleWindUnit() => windUnit.value = windUnit.value == WindUnit.kmh
      ? WindUnit.mph
      : WindUnit.kmh;

  String formatTemp(double value) =>
      '${value.toStringAsFixed(1)}${tempUnit.value.symbol}';

  String formatWind(double value) =>
      '${value.toStringAsFixed(1)} ${windUnit.value.symbol}';

  @override
  void dispose() {
    windUnit.dispose();
    tempUnit.dispose();
  }
}
