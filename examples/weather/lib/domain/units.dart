enum TempUnit {
  celsius('celsius', '°C'),
  fahrenheit('fahrenheit', '°F');

  const TempUnit(this.apiValue, this.symbol);
  final String apiValue;
  final String symbol;
}

enum WindUnit {
  kmh('kmh', 'km/h'),
  mph('mph', 'mph');

  const WindUnit(this.apiValue, this.symbol);
  final String apiValue;
  final String symbol;
}
