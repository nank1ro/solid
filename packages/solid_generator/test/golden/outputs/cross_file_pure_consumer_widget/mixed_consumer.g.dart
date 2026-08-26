// GAP 1 of the post-#106 residual gap survey — a MIXED file: a plain-class
// pure consumer (`SessionLogger`, the #106 shape already fixed) and a
// widget pure consumer (`WelcomeBanner`, the new shape this gap closes) in
// the SAME file. Proves the two lowering passes
// (`lowerPureConsumerWidgetReads` and `lowerPureConsumerCrossFileReads`)
// compose correctly against one shared `classRegistry` and a single
// `flutter_solidart` import gets added exactly once.
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'auth_repository.dart';

class SessionLogger {
  SessionLogger(this._authRepository);

  final AuthRepository _authRepository;

  bool hasSession() => _authRepository.session.value != null;
}

class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner(this.authRepository, {super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(authRepository.session.value ?? 'anonymous');
      },
    );
  }
}
