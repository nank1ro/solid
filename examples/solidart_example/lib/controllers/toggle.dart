import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ToggleController implements Disposable {
  final loggedIn = Signal<bool>(false, name: 'loggedIn');

  void toggle() => loggedIn.value = !loggedIn.value;

  @override
  void dispose() {
    loggedIn.dispose();
  }
}
