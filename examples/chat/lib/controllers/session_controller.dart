import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class SessionController implements Disposable {
  SessionController() {
    myUserId.value = 'me-${DateTime.now().millisecondsSinceEpoch}';

    logSession;
  }

  late final myUserId = Signal<String>.lazy(name: 'myUserId');

  late final logSession = Effect(() {
    print('session: ${myUserId.value}');
  }, name: 'logSession');

  @override
  void dispose() {
    logSession.dispose();
    myUserId.dispose();
  }
}
