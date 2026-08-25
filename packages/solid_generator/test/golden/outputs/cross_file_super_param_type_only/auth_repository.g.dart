import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository implements Disposable {
  final session = Signal<String?>(null, name: 'session');

  @override
  void dispose() {
    session.dispose();
  }
}
