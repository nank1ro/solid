import 'package:solid_annotations/solid_annotations.dart';

import '../domain/units.dart';

class UnitsController {
  @SolidState()
  TempUnit tempUnit = TempUnit.celsius;

  @SolidState()
  WindUnit windUnit = WindUnit.kmh;

  void setTempUnit(TempUnit unit) => tempUnit = unit;

  void setWindUnit(WindUnit unit) => windUnit = unit;

  void toggleTempUnit() => tempUnit = tempUnit == TempUnit.celsius
      ? TempUnit.fahrenheit
      : TempUnit.celsius;

  void toggleWindUnit() =>
      windUnit = windUnit == WindUnit.kmh ? WindUnit.mph : WindUnit.kmh;

  String formatTemp(double value) =>
      '${value.toStringAsFixed(1)}${tempUnit.symbol}';

  String formatWind(double value) =>
      '${value.toStringAsFixed(1)} ${windUnit.symbol}';
}
