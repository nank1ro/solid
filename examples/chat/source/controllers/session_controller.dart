import 'package:solid_annotations/solid_annotations.dart';

class SessionController {
  SessionController() {
    myUserId = 'me-${DateTime.now().millisecondsSinceEpoch}';
  }

  @SolidState()
  late String myUserId;

  @SolidEffect()
  void logSession() {
    print('session: $myUserId');
  }
}
