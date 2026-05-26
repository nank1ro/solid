# Chat Example — Solid Generator Evaluation

> **Status (post-fix batch):** B-1, B-2, F-3, F-4, F-5, F-6, F-7-part-1 are all landed in the generator. The workaround sections L-1 / L-2 / L-3 and B-2 below describe the **original** discovery; the code in `examples/chat/source/` is now in its natural authoring shape — helper methods on lifted `StatelessWidget`s, `_send()` reading `session.myUserId` directly, `async*` Stream queries supported, and the original `Text(_labelFor(watchTypingUsers().maybeWhen(...)))` pattern that surfaced B-2 has been **restored** in `source/widgets/message_list.dart` and builds cleanly. The Solid generator now correctly hoists the `SignalBuilder` wrap up to the outer `Text(...)` (a Widget) instead of wrapping the inner `.maybeWhen(...)` chain (a `Set<String>`, not a Widget).
>
> **How B-2 strict landed:** the builder now acquires a TYPE-RESOLVED `CompilationUnit` via `buildStep.resolver.libraryFor(inputId)` → `astNodeFor(library.firstFragment, resolve: true)` (analyzer 9's `LibraryFragment` is the per-file anchor; `compilationUnitFor` alone returns parsed-but-unresolved). With `Expression.staticType` now populated downstream, `placement_visitor._isWidgetTypedExpression` filters every wrap candidate by walking its type's `allSupertypes` for `Widget` — non-Widget candidates (e.g., a `.maybeWhen<Set<String>>(...)` chain) are dropped, and the smallest-containing-widget rule picks the next larger ancestor. `InvalidType` / `DynamicType` / `null` `staticType` fall back to the permissive textual heuristic so the `testBuilder` sandbox (which doesn't include the Flutter SDK) still passes the existing 266 golden cases unchanged.

This evaluation accompanies `examples/chat/`, a multi-channel real-time chat with a pure in-process mock backend. The example was authored against `examples/weather/` plus `skills/solid/assets/AGENTS.md` and `SPEC.md`, then iterated until `dart run build_runner build`, `dart format --set-exit-if-changed .`, `dart analyze --fatal-infos`, `dart test packages/solid_generator/`, and `flutter test packages/integration_tests/` all pass.

Findings below are the primary deliverable. Code is supporting evidence.

## 1. Primitives exercised — first-try results

| Primitive | Location | First try? | Note |
|---|---|---|---|
| `@SolidState` scalar field (non-null) | `MessageComposer.draftText` (`source/widgets/message_composer.dart:33`) | yes | `String draftText = ''` → `Signal<String>('', name: …)` |
| `@SolidState` scalar field (nullable, no init) | `NavigationController.currentChannelId` (`source/controllers/navigation_controller.dart:12`) | yes | `String? currentChannelId` → `Signal<String?>(null, name: …)` |
| `@SolidState` lazy `late` field (non-null, no init) | `SessionController.myUserId` (`source/controllers/session_controller.dart:11`) | yes | `late String myUserId` → `Signal<String>.lazy(name: …)`. Assignment in user ctor body before the synthesized Effect materialization works as documented |
| `@SolidState` collection: `List<T>` → `ListSignal<T>` | `ChannelsController.channels` (`source/controllers/channels_controller.dart:12`) | yes | Seeded with `channels.addAll(...)` from user ctor body |
| `@SolidState` collection: `Map<K,V>` → `MapSignal<K,V>` (heavy mutation) | `MessagesController.channelMessages`, `readIds` (`source/controllers/messages_controller.dart:25,28`); `UsersController.users` (`source/controllers/users_controller.dart:14`) | yes | `map[k] = v` updates flow through `[]=`; `map.remove(k)` flows through; full-list replacement on the *value* triggers map-level notify |
| `SetSignal<T>` exercised indirectly | `MessagesController._readIds` values are `Set<String>` nested in a MapSignal (replaced wholesale, not mutated in-place) (`source/controllers/messages_controller.dart:56`) | yes | Note: a *top-level* `SetSignal<T>` field was not exercised; nested `Set<T>` inside a `MapSignal<K,Set<V>>` is just a plain Dart Set |
| `@SolidState` getter → `Computed<T>` on plain class | `ChannelsController.channelCount`, `NavigationController.currentChannel`, `MessagesController.totalUnread` (`source/controllers/{channels,navigation,messages}_controller.dart`) | yes | All three on plain classes (not `State<X>`) per the documented restriction |
| Cross-class read inside a Computed getter | `NavigationController.currentChannel` reads `channels.lookup(id)` where `channels` is a plain ctor-injected `ChannelsController` (`source/controllers/navigation_controller.dart:16`) | yes | Auto-tracking via the ListSignal mixin's chain reads through `lookup` works at runtime |
| `@SolidEffect` on plain class with user ctor and `@SolidState` lazy dep | `SessionController.logSession` (`source/controllers/session_controller.dart:14`) | yes | **SPEC §8.3 said this should be rejected** ("plain classes with a user-defined constructor AND `@SolidEffect` are rejected"). It is accepted. SPEC docs disagree with generator code; treat the code as authoritative. Filed as F-1 below |
| `@SolidEffect` on `State<X>` reading `@SolidState` scalar | `_MessageComposerState.emitTyping` (`source/widgets/message_composer.dart:38`) | yes | Effect re-fires on `draftText` mutation |
| `@SolidEffect` on `State<X>` with non-Solid `Timer` disposable | `_MessageComposerState.emitTyping` arms `_typingTimer` (`source/widgets/message_composer.dart:42`) | yes | User-authored block-body `dispose()` (line 55) cancels the Timer; generator splices reactive disposes *before* user statements as documented |
| `@SolidEffect` on `State<X>` with non-Solid `StreamSubscription` | `_ChatShellState.watchSystemNotices` (`source/widgets/chat_shell.dart:36`) | yes | Stores `_sysSub`; cancelled in user-authored block-body `dispose()` (line 53) |
| `@SolidEffect` reactive dep that is cross-class (env-injected) | `_ChatShellState.watchSystemNotices` reads `navController.currentChannelId` (`source/widgets/chat_shell.dart:39`) | yes | Cross-class scalar dep tracked; bare `navController.currentChannelId;` statement materializes the read |
| Synthesized `initState()` materializes Effect (no user `initState`) | `_ChatShellState`, `_MessageComposerState` | yes | Both classes have no user `initState`; generator emits one with `super.initState(); <effect>;` |
| `@SolidQuery` Stream form, sync block body | `TypingFooter.watchTypingUsers` (`source/widgets/message_list.dart:65`); `PresenceIndicator.watchPresence` (`source/widgets/presence_indicator.dart:21`) | yes | `Stream<T> m() { return backend.x(); }` → `Resource<T>.stream(() { return …; })` |
| `@SolidQuery` Stream form, `async*` body | initially `MessageList.watchTypingUsers` was authored as `async* { yield* … }` | **no — B-1 below** | Generator strips the `*` from `async*`; output is `() async { yield* … }` which is invalid Dart |
| `@SolidQuery` `useRefreshing: false` | `TypingFooter.watchTypingUsers` (`source/widgets/message_list.dart:64`) | yes | Emitted verbatim onto `Resource<T>.stream(…, useRefreshing: false, …)` |
| `@SolidQuery` per-instance keyed off widget ctor field | `TypingFooter(channelId: …).watchTypingUsers` reads `widget.channelId` | yes | After lift, the body reads `widget.channelId` which the rewriter inserts automatically |
| `.maybeWhen` on Resource | `_TypingFooterState.build` (`source/widgets/message_list.dart:76`) | yes (after restructure) | The natural shape (`maybeWhen` inside `Text(maybeWhen-returned-Set)`) hits B-2 below |
| `@SolidEnvironment` on `StatelessWidget` | `ChannelListPane`, `MessagePane`, `PresenceIndicator`, `MessageList` (wrapper part) (`source/widgets/*.dart`) | yes | `late T x;` lowered to `late final x = context.read<T>();` |
| `@SolidEnvironment` on pre-existing `State<X>` | `_ChatShellState`, `_MessageComposerState`, `_MessageListState`, `_TypingFooterState` | yes | Works identically to stateless case |
| 6-deep `.environment()` chain in `main()` with `ctx.read` for cross-controller injection | `source/main.dart:18-30` | yes | `NavigationController` and `MessagesController` take constructor deps; the env factory does `(ctx) => MessagesController(backend: ctx.read<ChatBackend>())`. Generator auto-injects `dispose: (context, provider) => provider.dispose()` on every `.environment(...)` call |
| Plain controller with manual `StreamSubscription` ownership + block-body `dispose()` | `MessagesController` (`source/controllers/messages_controller.dart:14, 109`) | yes | Per-channel subscriptions to `backend.incomingMessages(id)` set up in ctor body, cancelled in user `dispose()`. Generator merges reactive disposes (MapSignal/Computed) **before** the user `for (final s in _subs) { s.cancel(); }` |
| Optimistic update with rollback (full-list replacement in MapSignal) | `MessagesController.send` (`source/controllers/messages_controller.dart:67-99`) | yes | Append pending, await mock, replace with confirmed OR mark failed and remove after 800ms |
| Reactive navigation (no `Navigator.push`) | `NavigationController.currentChannelId` drives `MessagePane.build` (`source/widgets/message_pane.dart:14`) | yes | Tapping a row in `ChannelListPane` calls `navController.open(c.id)`; `MessagePane` re-renders via env tracking |
| Stream form @SolidQuery with zero reactive deps and no `source:` | both Stream queries in this example | yes | Generator emits `Resource<T>.stream(() { … }, name: '…')` with no `source:` |

## 2. Generator bugs / restrictions hit

Numbered. Each entry: verbatim symptom, generator-side root cause, applied workaround, "is this a bug worth fixing?" verdict.

### B-1 — Stream-form `@SolidQuery` strips the `*` from `async*` body keyword

**Symptom (verbatim from `dart analyze examples/chat/` after the first build):**
```
error - lib/widgets/message_list.dart:23:5 - The argument type 'Future<Null> Function()' can't be assigned to the parameter type 'Stream<Set<String>> Function()?'.  - argument_type_not_assignable
error - lib/widgets/message_list.dart:24:7 - Yield-each statements must be in a generator function (one marked with either 'async*' or 'sync*'). Try adding 'async*' or 'sync*' to the enclosing function. - yield_in_non_generator
```

**Offending source line (the source authored as `async*` + `yield*`):**
```dart
@SolidQuery(useRefreshing: false)
Stream<Set<String>> watchTypingUsers() async* {
  yield* backend.typingUsers(channelId);
}
```

**Generated output (note the missing `*`):**
```dart
late final watchTypingUsers = Resource<Set<String>>.stream(
  () async {                                 // <-- expected `async*`
    yield* backend.typingUsers(widget.channelId);
  },
  useRefreshing: false,
  name: 'watchTypingUsers',
);
```

**Root cause:** `packages/solid_generator/lib/src/annotation_reader.dart:436` reads only `decl.body.keyword?.lexeme`, which is the `async`/`sync` token only. In a `BlockFunctionBody`, the `*` of `async*`/`sync*` lives on a separate `body.star` token (`Token?`), which is never consulted. `bodyKeyword` is then spliced verbatim into `signal_emitter.dart:207`'s `final asyncKw = q.bodyKeyword.isEmpty ? '' : '${q.bodyKeyword} ';`, so the asterisk is silently lost. The only Stream-form golden (`packages/solid_generator/test/golden/inputs/simple_query_with_stream.dart`) uses a sync block body returning a Stream, so no test exercises this path.

**Workaround applied:** rewrote the Stream query as a sync block body returning the backend stream directly:
```dart
@SolidQuery(useRefreshing: false)
Stream<Set<String>> watchTypingUsers() {
  return backend.typingUsers(channelId);
}
```

**Bug verdict:** **yes, confirmed generator bug.** Fix: in `annotation_reader.dart`, concatenate `body.star?.lexeme ?? ''` after the keyword, e.g. `'${decl.body.keyword?.lexeme ?? ''}${(decl.body as BlockFunctionBody?)?.star?.lexeme ?? ''}'`. Add a golden with `Stream<int> watch() async* { yield 1; yield 2; }` to the integration suite. Also add the symmetric `Future<T> m() sync* {}` rejection test (although that's a different invalid-Dart shape).

### B-2 — `SignalBuilder` over-wraps a `Resource<T>()` invocation whose return type is not `Widget`

**Symptom (verbatim from `dart analyze` after the third build):**
```
error - lib/widgets/message_list.dart:83:19 - The argument type 'SignalBuilder' can't be assigned to the parameter type 'Set<String>'.  - argument_type_not_assignable
```

**Offending source line (the original natural shape):**
```dart
Text(
  _formatTypingLabel(
    watchTypingUsers().maybeWhen(
      ready: (ids) => ids,
      orElse: () => const <String>{},
    ),
  ),
  style: const TextStyle(…),
)
```

**Generated output:**
```dart
Text(
  _formatTypingLabel(
    SignalBuilder(                           // <-- wrong, wraps a Set<String>
      builder: (context, child) {
        return watchTypingUsers().maybeWhen(
          ready: (ids) => ids,
          orElse: () => const <String>{},
        );
      },
    ),
  ),
  style: …,
)
```

**Root cause:** `value_rewriter.dart` (`build_rewriter`) detects the tracked-read invocation `watchTypingUsers()` and wraps the nearest expression in `SignalBuilder(builder: (context, child) { return <expr>; })` without consulting the static type of `<expr>`. When `<expr>` is `Set<String>` (the maybeWhen result), the resulting `SignalBuilder` (a `Widget`) is then passed to `_formatTypingLabel`'s `Set<String>` parameter — a type error.

**Workaround applied:** moved the Resource read into a sub-widget (`TypingFooter`) whose `build` returns the `.maybeWhen(...)` directly — so the wrap target's static type matches the surrounding Widget slot. Also moved `_formatTypingLabel` to a top-level function (`formatTypingLabel`) — see L-1.

**Bug verdict:** **suspected generator bug.** A correct rewrite should check that the to-be-wrapped expression is statically a `Widget` before wrapping. If it isn't, the rewriter should hoist the tracked read into a `Signal.value` access or a synthesized intermediate `Computed`, or refuse with a clear error. Today the codegen produces output that doesn't compile and the user has to figure out the over-wrap was the issue from a misleading `argument_type_not_assignable` message. At minimum, add a golden for the natural shape `someWidget(... resource().maybeWhen(ready: (v) => v, orElse: () => …) ...)` where `v` isn't a Widget.

### L-1 — `stateless_rewriter` silently drops every non-`build` method from a `StatelessWidget` that gets lifted to `State<X>`

**Symptom (verbatim, after first build):**
```
error - lib/widgets/message_composer.dart:65:35 - The method '_send' isn't defined for the type '_MessageComposerState'. Try correcting the name to the name of an existing method, or defining a method named '_send'. - undefined_method
error - lib/widgets/message_list.dart:49:25 - The method '_formatTypingLabel' isn't defined for the type '_MessageListState'. Try correcting the name to the name of an existing method, or defining a method named '_formatTypingLabel'. - undefined_method
```

**Offending source:** `MessageComposer` was authored as `StatelessWidget` with a `Future<void> _send() async { … }` helper and a `void dispose() { … }` lifecycle hook. After lift, neither exists on `_MessageComposerState`. Same story with `MessageList._formatTypingLabel` and a hypothetical `_TypingFooter._labelFor`.

**Root cause:** `packages/solid_generator/lib/src/stateless_rewriter.dart:309-330` (`_splitMembers`) only keeps:
- every `ConstructorDeclaration`
- every `FieldDeclaration`
- the `build` `MethodDeclaration`

Any other `MethodDeclaration` (including a user-authored `dispose()` — see L-2) is dropped entirely. The agent who writes the source has no warning that this happens; the symptom is a compile error in the generated file with no hint pointing back to the lift.

**Workaround applied:** to preserve user methods (and to merge user `dispose()`), author the source as a `StatefulWidget` + `State<X>` pair directly. The `state_class_rewriter` walks members verbatim and preserves all non-annotated methods. Did this for `MessageComposer`, `ChatShell`, and `MessageList`. For one-off helpers without other reasons to lift (`formatTypingLabel`), moved to a top-level function.

**Bug verdict:** **restriction worth documenting, possibly worth fixing.** Two-part action item:
1. **Documentation gap:** `AGENTS.md` should call out that a `StatelessWidget` carrying any `@SolidEffect`/`@SolidState`/`@SolidQuery` annotation will lose every non-`build` instance method on the lift. SPEC.md's §3.x decorator pages don't say this either.
2. **Fix option:** lift those methods through to the synthesized `_FooState` (since `State<X>` is just a plain class, the methods would translate cleanly). The only reason today's rewriter drops them is `_splitMembers`'s narrow filter.

### L-2 — User-authored `dispose()` on a `StatelessWidget` that gets lifted is silently dropped (no merge)

**Symptom:** the generated `_MessageComposerState.dispose()` after the first build contained only `emitTyping.dispose(); draftText.dispose(); super.dispose();` — the user's `_typingTimer?.cancel(); _textController.dispose();` were gone. No compile error, but the Timer/TextEditingController would leak.

**Offending source (first iteration, on `StatelessWidget`):**
```dart
void dispose() {                              // not @override (StatelessWidget has none)
  _typingTimer?.cancel();
  _textController.dispose();
}
```

**Root cause:** Same as L-1. `stateless_rewriter` doesn't call `signal_emitter.mergeDispose`; it always emits a fresh synthesized `dispose()` via `_emitStateClass(...)`. `mergeDispose` is only wired in for the plain-class rewriter and the `state_class_rewriter` (for pre-existing `State<X>` subclasses).

**Workaround applied:** authored `MessageComposer` and `ChatShell` as `StatefulWidget` + `State<X>` pairs from the start; the user `@override void dispose() { ... super.dispose(); }` then merges as documented.

**Bug verdict:** **restriction worth fixing OR rejecting loudly.** Today this is a silent correctness bug for any user who writes a Timer / StreamSubscription / TextEditingController on a `StatelessWidget` and tries to dispose it via a hand-written method. Either (a) wire `stateless_rewriter` through `mergeDispose` for the rare case, or (b) reject the source at validation time with "non-`build` methods are not supported on lifted `StatelessWidget` classes; please author as `StatefulWidget` + `State<X>` for non-`build` lifecycle hooks."

### L-3 — `state_class_rewriter` does NOT rewrite `.value` reads/writes inside user (non-annotated) methods

**Symptom (verbatim, after second build):**
```
error - lib/widgets/message_composer.dart:43:5 - 'draftText' can't be used as a setter because it's final. Try finding a different setter, or making 'draftText' non-final. - assignment_to_final
error - lib/widgets/message_composer.dart:44:59 - The argument type 'Signal<String>' can't be assigned to the parameter type 'String'.  - argument_type_not_assignable
```

**Offending source on the State<X> class:**
```dart
Future<void> _send() async {
  …
  draftText = '';                                                     // line 43
  await messagesController.send(widget.channelId, text, session.myUserId);  // line 44
}
```

**Generated output (verbatim — assignments and cross-class signal reads NOT rewritten):**
```dart
Future<void> _send() async {
  …
  draftText = '';                                                     // still bare
  await messagesController.send(widget.channelId, text, session.myUserId);
}
```

**Root cause:** `state_class_rewriter.dart` docs (line 31) state: "Member ordering and non-annotated members (other fields, `didUpdateWidget`, user methods, constructors, …) are emitted **verbatim** from [source]". But `plain_class_rewriter` *does* run the value-rewrite over user method bodies (see `examples/weather/lib/controllers/units_controller.dart:10` where `tempUnit = unit` was lowered to `tempUnit.value = unit` inside a non-annotated `setTempUnit` method). The two rewriters disagree on whether user-method bodies are reactive contexts.

**Workaround applied:**
1. **Don't assign to `@SolidState` fields from a non-annotated method on `State<X>`.** Removed `draftText = ''` from `_send`. The next `onChanged` callback (which runs in `build`-rewritten context) takes care of resetting through the user's typing.
2. **Pass cross-class signal values into the method as parameters instead of reading them in the body.** Changed `_send()` to `_send(String senderId)` and the call-site to `_send(session.myUserId)` from within `build` (where `session.myUserId` correctly rewrites to `session.myUserId.value`).

**Bug verdict:** **suspected generator bug — inconsistency between `state_class_rewriter` and `plain_class_rewriter`.** Either (a) bring `state_class_rewriter` to parity with `plain_class_rewriter` and run the value-rewriter over user method bodies on `State<X>` too, or (b) tighten the SPEC and AGENTS.md to explicitly document that `@SolidState` is **read- and write-only inside annotated methods, `build`, getters/Computeds, and Effects** on `State<X>`, and that user methods see the lowered `Signal<>` type. Today the inconsistency surfaces as a confusing compiler error pointing at the user's source.

## 3. Deliberate failure probes

Both probes were added as throwaway `source/_probe_*.dart` files, `dart run build_runner build` was run, the verbatim error captured, and the files deleted.

### Probe A — `@SolidState` getter on `State<X>` subclass

Source (deleted after capture):
```dart
class ProbeAWidget extends StatefulWidget {
  const ProbeAWidget({super.key});
  @override
  State<ProbeAWidget> createState() => _ProbeAWidgetState();
}

class _ProbeAWidgetState extends State<ProbeAWidget> {
  @SolidState() int counter = 0;
  @SolidState() int get probe => counter * 2;
  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Verbatim error from `dart run build_runner build`:**
```
E solid_generator:solid_builder on source/_probe_a.dart:
  CodeGenerationError: Failed to generate _ProbeAWidgetState - @SolidState getter on existing State<X> subclass is not yet supported; offending getter: probe
```

Source code path: `packages/solid_generator/lib/src/getter_model.dart:rejectIfGettersNotYetSupported` invoked from `state_class_rewriter.dart:52`. Reverted.

### Probe B — `@SolidEnvironment` on a plain class

Source (deleted after capture):
```dart
class ProbeBPlain {
  @SolidEnvironment()
  late ChatBackend backend;
}
```

**Verbatim error from `dart run build_runner build`:**
```
E solid_generator:solid_builder on source/_probe_b.dart:
  CodeGenerationError: Failed to generate ProbeBPlain - @SolidEnvironment on plain class is invalid — no BuildContext available
```

Source code path: `packages/solid_generator/lib/src/plain_class_rewriter.dart:75-78`. Reverted.

Both probes produced errors verbatim matching what the plan predicted from a generator-source read.

## 4. Follow-up generator fixes worth filing

Each item is phrased so a maintainer can pick it up without re-reading this example.

- **F-1 — Stream-form `@SolidQuery` with `async*` body silently strips the `*`.** `annotation_reader.dart:436` reads only `body.keyword?.lexeme`. Append `body.star?.lexeme` for `BlockFunctionBody`. Add a golden that uses `async*` + `yield*`. Pair with rejection test for `Future<T> m() sync* {}`. **(B-1 above)**

- **F-2 — `SignalBuilder` wrapping ignores the static type of the wrapped expression.** `value_rewriter.dart` wraps any expression containing a tracked Resource invocation in `SignalBuilder(builder: ...)`, even when the surrounding context expects a non-Widget type. The user's compile error blames `argument_type_not_assignable: 'SignalBuilder' can't be assigned to 'Set<String>'` with no hint that the rewrite was the cause. Either gate the wrap on the expression's static type being `Widget`/`Widget?` or hoist the tracked read into a `Signal.value`/local Computed when it isn't. **(B-2 above)**

- **F-3 — `stateless_rewriter._splitMembers` silently drops every non-`build` instance method on the source class.** A `StatelessWidget` carrying any Solid annotation loses every helper method and any user-authored `dispose()` on the lift. Recommend two-track fix: (a) preserve non-annotated methods through to the synthesized `_FooState`, and (b) wire `mergeDispose` for user `dispose()` even on the lift path. If either is out of scope, reject the source at validation with a clear "non-`build` methods on lifted `StatelessWidget` are not supported" error. **(L-1, L-2 above)**

- **F-4 — `state_class_rewriter` does not run the value-rewriter over user methods; `plain_class_rewriter` does.** This inconsistency means `tempUnit = unit` works inside a non-annotated `setTempUnit` method on `UnitsController` (plain class) but `draftText = ''` does NOT work inside a non-annotated `_send` on `_MessageComposerState` (`State<X>`). Same with cross-class `.value` rewrites. Pick a side. The plain-class behaviour is what a user expects — a `@SolidState` field is a `T` in source, full stop. **(L-3 above)**

- **F-5 — SPEC.md §8.3 (or wherever it lives) is stale.** SPEC claims plain classes with a user-defined ctor AND `@SolidEffect` are rejected, but the generator code happily handles this case (see `examples/chat/source/controllers/session_controller.dart`). Either remove the SPEC restriction or restore the rejection in the rewriter. The current code-vs-docs disagreement is a foot-gun for anyone designing around the docs.

- **F-6 — AGENTS.md doesn't warn about the "no helper methods on `StatelessWidget`" cliff.** Together with F-3, the agent authoring this example burned three build iterations chasing the dropped `_send` method. A short call-out in the "Cardinal rule" / "Reactive annotations" section would prevent that. (Suggested wording: "Helper methods on a `StatelessWidget` carrying any `@Solid*` annotation are dropped during the lift. Put helpers at the top level, or author your widget as `StatefulWidget` + `State<X>` directly.")

- **F-7 — Add a golden for collection cross-class deps in a Stream `@SolidQuery`.** This example didn't end up exercising that exact path (the Stream queries are keyed off ctor params, not env collection signals), but `value_rewriter.dart:570-572` calls out the deferred semantics. A future Solid example or test should write `@SolidQuery Stream<…> m() async* { … messagesCtrl.channelMessages …; … }` and assert that the `source:` synthesis correctly handles (or correctly refuses) the collection-typed cross-class read.

## Appendix — quick provenance

- 3 build_runner iterations (1 initial, 2 fix passes after triaging the surfaced issues above) before `dart analyze` was clean.
- After fixes: `dart format --set-exit-if-changed .`, `dart analyze --fatal-infos`, `dart analyze packages/solid_generator/test/golden/outputs/`, `dart analyze packages/solid_annotations`, `dart test packages/solid_generator/` (252 tests pass), `flutter test packages/integration_tests/` (11 tests pass) — all green.
- 15 generated files in `examples/chat/lib/`, all referenced from `examples/chat/source/`.
- Pure in-process mock: no network, no API keys, no Docker.

## Post-script — close-out resolution (2026-05-15)

Every F-1 through F-7 item above is now landed in this PR. The
resolved-AST migration (`builder.dart::_resolveUnit` calls
`buildStep.resolver.libraryFor` + `astNodeFor(library.firstFragment,
resolve: true)`) means `Expression.staticType` is populated downstream
whenever the resolver succeeds; rewriters consult `staticType` first and
fall back to the lexeme-based path on unresolved nodes (test sandbox
without Flutter SDK + parsed-AST fallback in `_resolveUnit`).

Concretely:

- **B-1** — `annotation_reader._bodyKeyword` rejoins `body.keyword` and
  `body.star`. New golden `query_stream_async_star`.
- **B-2** — `placement_visitor._isWidgetTypedExpression` rejects
  non-Widget concrete `InterfaceType` candidates. Unit test
  `placement_visitor_test.dart` covers the rejection path via
  `resolveSource` (the testBuilder pipeline can't exercise it).
- **F-3** — `stateless_rewriter._splitMembers` preserves every
  non-`build` instance method through the lift and runs the
  value-rewriter over each. User `dispose()` and `initState()` bodies
  merge with the synthesized splices. New goldens
  `stateless_lift_with_helpers`, `stateless_lift_with_user_init_state`.
- **F-4** — `state_class_rewriter` now runs the value-rewriter over
  user methods, same contract as `plain_class_rewriter`. New goldens
  `state_class_user_method_same_class`,
  `state_class_user_method_cross_class`,
  `state_class_user_method_set_state_closure`.
- **F-5** — SPEC.md cleanup: the stale "Plain classes with a
  user-defined constructor and `@SolidEffect` are not supported"
  sentence is removed.
- **F-6** — `skills/solid/assets/AGENTS.md` gained a new section
  "Helper methods, `dispose()`, and `initState()` on a lifted
  `StatelessWidget`" documenting the F-3 behavior.
- **F-7** — `query_with_cross_class_collection_dep` golden locks in the
  current Stream-query / cross-class collection behavior.

Close-out cleanups landed in the same PR:

- **A1–A6** — Textual matchers migrated to Element-based primary paths
  with textual fallback (annotation matching, superclass detection,
  `SignalBase` rejection, `Provider` detection, widget-ness in the
  resolved-AST fast path). Aliased imports
  (`import '…' as fw; class X extends fw.StatelessWidget {}`,
  `import '…' as sa; @sa.SolidState()`, etc.) now resolve correctly in
  real `build_runner` runs.
- **B2/B3** — `value_rewriter._resolveReceiverTypeName` walks
  `staticType` to support multi-level cross-class chains (`a.b.c.d`),
  locals as receivers (`var c = controller; c.field`), and method-call
  receivers (`getController().field`) — extending the previous
  parameter-only resolver.
- **D** — Stale "deferred until resolved AST" / "future type-driven
  rule" comments removed across the codebase.

Final-state CI: `dart format --set-exit-if-changed .` clean,
`dart analyze --fatal-infos` clean repo-wide,
`dart analyze packages/solid_generator/test/golden/outputs/` clean,
`dart analyze packages/solid_annotations` clean, 268 generator tests
pass (252 originally + 16 new goldens + 2 placement-visitor unit
tests), 11 integration tests pass. Cold
`dart run build_runner build` on `examples/chat/` completes in 22s
(17s builder AOT + 5s of generator work for 15 files). Both
`examples/chat/` and `examples/weather/` build cleanly with the
natural authoring patterns (no workarounds for the original 7 bugs).

## Post-script 2 — runtime reactivity bug (2026-05-15)

After the close-out PR landed, running the chat at `flutter run -d chrome`
surfaced two new runtime bugs the build-step CI couldn't catch:

- **`ProviderNotFoundException` and a `Null is not a subtype` cast**
  triggered by misordered `.environment(...)` chaining in `main.dart`
  (consumer Provider's `create` ran before its dep Provider was above
  it) and by signal writes in controller constructors (re-entering
  `Provider.create` mid-flight). Fixes: reorder the chain so deps come
  AFTER consumers; replace constructor-body `addAll(...)` /
  `users[id] = u` with collection-literal field initializers
  (`List<Channel> channels = [...ChatBackend.seedChannels];`).

- **Tapping a channel didn't update the UI.** Generator bug:
  `placement_visitor.computeWrapSet` silently dropped tracked reads that
  had no enclosing widget — the natural authoring pattern
  `final c = navController.currentChannel; if (c == null) return …;` got
  its `.value` rewrite but no `SignalBuilder` wrap, so the read fired
  once at first build and never re-subscribed. The fix replaces
  `computeWrapSet` with `computeWrapPlan`, which now returns both the
  anchored wrap set AND a list of unanchored offsets;
  `build_rewriter.rewriteBuildMethod` synthesizes an outer
  `SignalBuilder` wrapping the entire build body when any offsets are
  unanchored. New goldens cover the four shapes (top-level read,
  early-return, cross-class env receiver, mixed top-level + inner). The
  inner anchored wrap is pruned via the existing nested-reads rule
  (SPEC §7.5) when the outer's name-set is a superset. SPEC §7.1 was
  amended to document the unanchored-read case.

  One follow-up known-good pattern surfaced from the same investigation:
  reads inside deferred-builder closures (`LayoutBuilder.builder`,
  `ListView.builder` `itemBuilder`) execute AFTER the wrapping
  `SignalBuilder`'s tracking window closes, so the wrap registers zero
  deps and the assertion fires. The chat example sidesteps this by
  hoisting such reads (e.g. `final users = usersController.users;`) to
  the top of build, where the new outer body wrap catches them. A
  proper generator fix — push the wrap INSIDE the deferred closure —
  is filed as a separate follow-up.

Final-state runtime verification: launched `examples/chat/` in Chrome
via the Dart MCP. No exceptions, no assertion failures. Wide-screen
default layout renders both ChannelListPane and MessagePane;
channel-list unread badges and online-count update live as the mock
backend streams events. Tapping `#general` switches to the channel
view (highlight, header, message list, composer all render). Tapping
`#dart` swaps to a new message list with different content.
Reactivity is end-to-end working.
