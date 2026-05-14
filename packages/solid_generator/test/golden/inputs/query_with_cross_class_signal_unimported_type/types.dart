// A plain Dart enum declared in a sibling file. `controllers.dart` imports
// this file to type its `@SolidState Unit unit` field; `widget.dart` does
// NOT import it, because the widget's source body never names `Unit`
// textually — it only writes `settings.unit`. The generator must inject the
// import into `widget.g.dart` so the synthesized `Computed<(int, Unit)>`
// Record resolves at lib-time.

enum Unit { a, b }
