// Query counterpart of `cross_file_qualified_registry_disambiguation`
// (issue #110 parity): two DIFFERENT classes named `Repo`, one in
// `repo_a.dart` with a REAL `@SolidQuery items()`, the other in
// `repo_b.dart` with an ORDINARY `items()` method of the same name and
// shape (plus an unrelated `@SolidQuery` of its own — see that file's
// comment for why). Both are reached from this PURE CONSUMER
// `StatelessWidget` via plain constructor injection — `repo_b.dart`'s
// `Repo` imported under a prefix so both bare and prefixed references
// coexist without a compile-time ambiguous-import error.
//
// `_populateCrossFileTypes`'s cross-file walk seeds a SINGLE 'Repo' entry
// into `wantedTypes`, then finds BOTH classes across this file's two
// imports — each contributes a distinct origin to
// `classQueryNamesOrigins['Repo']` (`{'items'}` from `repo_a.dart`,
// `{'otherQuery'}` from `repo_b.dart`), so the name is flagged ambiguous in
// `classQueryNamesShadowedNames` and stripped from the flat
// `classQueryNames`.
//
// At rewrite time, `a`'s resolved `staticType` points at `repo_a.dart`'s
// `Repo`; `b`'s points at `repo_b.dart`'s `Repo`. Each receiver's tier-1
// URI matches ONLY its own class's recorded origin: `a.items()` resolves
// against `{'items'}` (a match — tracked, `SignalBuilder`-wrapped) while
// `b.items()` resolves against `{'otherQuery'}` (`items` is NOT in that
// set — no match, no tracking, no wrap). Never the other way around.
import 'package:flutter/widgets.dart';

import 'repo_a.dart';
import 'repo_b.dart' as repo_b;

class RepoScreen extends StatelessWidget {
  const RepoScreen(this.a, this.b, {super.key});

  final Repo a;
  final repo_b.Repo b;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<List<String>>(
          future: a.items(),
          builder: (context, snapshot) => const SizedBox.shrink(),
        ),
        FutureBuilder<List<String>>(
          future: b.items(),
          builder: (context, snapshot) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
