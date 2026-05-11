import 'package:solid_annotations/solid_annotations.dart';

class ToggleController {
  @SolidState()
  bool loggedIn = false;

  void toggle() => loggedIn = !loggedIn;
}
