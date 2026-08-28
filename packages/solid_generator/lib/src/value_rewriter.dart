import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/query_model.dart';

/// A single value-level edit emitted by [collectValueEdits].
///
/// [offset] and [end] are positions in the full source string. [end] equal
/// to [offset] denotes a pure insertion (the common `.value` append case).
class ValueEdit {
  /// Creates an edit that replaces `[offset, end)` with [replacement].
  const ValueEdit(this.offset, this.end, this.replacement);

  /// Inclusive start offset in the source string.
  final int offset;

  /// Exclusive end offset in the source string.
  final int end;

  /// Replacement text to splice in for the range `[offset, end)`.
  final String replacement;
}

/// The output of [collectValueEdits]: a set of textual edits plus the
/// offsets of reads that count as "tracked" for SignalBuilder placement.
///
/// A tracked read is one that must cause its enclosing widget subtree to
/// subscribe. Writes never appear here; reads inside user-interaction
/// callbacks or `<field>.untracked` reads are excluded.
class ValueRewriteResult {
  /// Creates a result holding [edits], [trackedReadNamesByOffset],
  /// [trackedReadNames], [trackedQueryNames], [trackedCrossClassReadNames],
  /// and [selfCycleFound].
  const ValueRewriteResult(
    this.edits,
    this.trackedReadNamesByOffset,
    this.trackedReadNames,
    this.trackedQueryNames,
    this.trackedCrossClassReadNames,
    // Positional to keep the constructor signature consistent with the
    // list/map-typed args above; the field is single-use sentinel data.
    // ignore: avoid_positional_boolean_parameters
    this.selfCycleFound,
  );

  /// Source edits to apply for `.value` / interpolation rewrites.
  final List<ValueEdit> edits;

  /// Source offsets of reads that must be tracked for SignalBuilder
  /// placement, keyed by the `@SolidState` field name or `@SolidQuery`
  /// method name the read references. Map insertion order is
  /// source-first-appearance, so `.keys` iteration is stable. Drives the
  /// placement pass's same-signal nested-wrap collapse — an inner wrap is
  /// dropped iff its name set is a subset of the outer's.
  final Map<int, String> trackedReadNamesByOffset;

  /// Names of `@SolidState` field/getter identifiers read in tracked
  /// position, in source-first-appearance order, deduplicated.
  final List<String> trackedReadNames;

  /// Same-class `@SolidQuery` method names invoked as zero-arg tracked calls,
  /// in source-first-appearance order, deduplicated. Disjoint from
  /// [trackedReadNames]; a query dep contributes element type
  /// `ResourceState<T>` (read via `<name>.state`) to the synthesized
  /// Record-Computed source.
  final List<String> trackedQueryNames;

  /// Cross-class `@SolidState` reads — `<envField>.<signalName>` shapes where
  /// `<envField>` is an `@SolidEnvironment` field on the enclosing class and
  /// `<signalName>` is a `@SolidState` field/getter on the env-field's type.
  /// Source-first-appearance order, deduplicated. Drives `Resource.source:`
  /// synthesis for `@SolidQuery` bodies that depend on cross-class signals;
  /// the same Signal would otherwise be read via `.value` (subscribing
  /// `Computed`/`Effect` bodies at runtime) but a Resource needs an explicit
  /// `source:` to re-fetch on dependency changes. Disjoint from
  /// [trackedReadNames] (which is same-class only).
  final List<CrossClassDep> trackedCrossClassReadNames;

  /// True if the visitor saw a zero-arg call to its own [collectValueEdits]
  /// `currentMember` — i.e. a `@SolidQuery` body invokes itself. Consumed
  /// by `readSolidQueryMethod` to surface the self-cycle error. Always
  /// `false` when `currentMember` is null (effect / state-getter callers).
  final bool selfCycleFound;
}

/// True if [name] matches the untracked-callback pattern: a named argument
/// whose name starts with `on` followed by an uppercase ASCII letter.
/// Matches every Flutter built-in callback (`onPressed`, `onTap`,
/// `onChanged`, `onHorizontalDragUpdate`, …) and any user-defined `on*`
/// callback on a custom widget (`onTrigger`, `onRefresh`, …).
///
/// The rule is paired with a `FunctionExpression` value guard at the call
/// site, so non-callback `on*` named args (e.g. an enum or a Duration)
/// never match.
bool _isOnPrefixedCallbackName(String name) {
  if (name.length < 3) return false;
  if (!name.startsWith('on')) return false;
  final third = name.codeUnitAt(2);
  return third >= 0x41 && third <= 0x5A; // 'A'..'Z'
}

/// Walks [node] and returns every offset-based value edit plus the
/// tracked-read offsets that downstream placement needs.
///
/// [reactiveFields] is the name-set of `@SolidState` fields and getters
/// declared on the enclosing class. The rewrite is name-based; the
/// `type_aware_no_double_append` golden locks in the no-double-append
/// guarantee at the name-set boundary. Cross-file resolution for
/// `@SolidEnvironment` types is wired via `BuildStep.resolver` (see
/// `builder.dart::_populateCrossFileTypes`) — `[classRegistry]` and
/// `[classCollectionFields]` already include cross-file entries by the
/// time this function is called. Cross-class receiver resolution uses
/// `staticType` when available (locals, method-call receivers, multi-level
/// chains) and falls back to AST parameter or instance-field inspection when
/// unresolved (test sandboxes without the Flutter SDK, or a constructor-
/// injected field like `final AuthRepository _authRepository;`).
///
/// [queryNames] is the name-set of `@SolidQuery` methods declared on the
/// enclosing class. Zero-argument `MethodInvocation`s whose target is
/// a bare `SimpleIdentifier` matching a query name (and not shadowed, and not
/// inside an untracked context) have their offsets recorded in
/// [ValueRewriteResult.trackedReadNamesByOffset] so SignalBuilder placement
/// can wrap their enclosing widget subtree. NO source edit is emitted for
/// the call expression itself — the call survives byte-identical because the
/// lowered `<name>()` resolves through `Resource<T>.call() => state` to
/// upstream extensions on `ResourceState<T>`.
///
/// [classRegistry] is the cross-class reactivity map (class name → reactive
/// field/getter names). Single-level `<receiver>.<reactiveField>` is
/// handled in [_ValueRewriteVisitor.visitPrefixedIdentifier]; multi-level
/// chains (`a.b.c.d`) and non-SimpleIdentifier receivers
/// (`getController().field`) are handled in [_ValueRewriteVisitor.
/// visitPropertyAccess] via `staticType`-based receiver resolution. The
/// receiver shape also includes `@SolidEnvironment late T name;`
/// host-class fields via [environmentFields]. Empty registry = no-op for
/// the cross-class branch; existing same-class behavior unchanged.
///
/// [environmentFields] is the host class's `@SolidEnvironment` field map
/// (`fieldName -> typeText`) — the sibling slice of the cross-class
/// rewrite. Empty map → no-op for the env-field branch.
///
/// [node] is typically the `build()` `MethodDeclaration` or the body
/// expression of a `@SolidState` getter. Both share the same
/// identifier-rewrite contract; only `build()` consumes
/// [ValueRewriteResult.trackedReadNamesByOffset] for SignalBuilder placement.
///
/// [ValueRewriteResult.trackedReadNames] holds only `@SolidState` field /
/// getter reads. Same-class `@SolidQuery` calls in tracked position are
/// recorded separately in [ValueRewriteResult.trackedQueryNames] so the
/// emitter can pick the correct Record-Computed element type
/// (`ResourceState<T>` vs `T`) and read expression (`.state` vs `.value`).
///
/// [currentMember] names the enclosing member when the body being walked is
/// a `@SolidQuery` — pass the method's own name so a zero-arg call to it
/// inside the body is detected as a self-cycle and surfaced via
/// [ValueRewriteResult.selfCycleFound]. Pass `null` for non-query callers
/// (state getters, effects, build bodies).
///
/// [classRegistryOrigins] and [classCollectionFieldsOrigins] (issue #110)
/// are the per-name origin-qualified counterparts of [classRegistry] /
/// [classCollectionFields] — `name -> originUri -> fields` — populated by
/// `builder.dart` ONLY for names it could not resolve unambiguously: two or
/// more distinct cross-file classes sharing a simple name, or a cross-file
/// class whose name is ALSO declared locally in the consuming file.
/// [classRegistryShadowedNames] is the exact set of such flagged names.
/// Every name NOT in that set is served from the flat, name-keyed maps
/// exactly as before this issue existed; a flagged name rewrites only when
/// the receiver's resolved `staticType` (tier 1) points at a library URI
/// matching one of its recorded origins — see
/// [_ValueRewriteVisitor._fieldsForCrossClassName] for the full invariant.
/// Empty (the default) for every caller that has no
/// origin data to offer, which degrades this exactly to the pre-#110
/// name-only behavior.
///
/// [classQueryNames] is the cross-class `@SolidQuery` name map (class name →
/// `@SolidQuery` method names) — the query counterpart of [classRegistry].
/// A zero-arg cross-instance `<receiver>.<queryName>()` call whose
/// receiver's resolved declared type names a class in this map is a tracked
/// read (offset recorded, same as a same-class query call) but receives NO
/// source edit: the call already lowers to `Resource.call() => state` and
/// every trailing `.isLoading`/`.asReady`/`.asError` chain resolves through
/// upstream `flutter_solidart` extensions unchanged. Empty (the default)
/// for every caller that has not opted into cross-class query recognition —
/// currently only build-method callers.
///
/// [classQueryNamesOrigins] and [classQueryNamesShadowedNames] are the query
/// counterparts of [classRegistryOrigins] / [classRegistryShadowedNames]
/// (issue #110) — a name `builder.dart` could not resolve unambiguously by
/// simple name alone (two-plus distinct cross-file query-bearing classes
/// sharing the name, or a cross-file class whose name is ALSO declared
/// locally) routes through [classQueryNamesOrigins] with a mandatory tier-1
/// library-URI match instead of the flat [classQueryNames] — see
/// [_ValueRewriteVisitor._queryNamesForCrossClassName].
ValueRewriteResult collectValueEdits(
  AstNode node,
  Set<String> reactiveFields,
  String source, {
  Set<String> queryNames = const {},
  String? currentMember,
  Map<String, Set<String>> classRegistry = const {},
  Map<String, String> environmentFields = const {},
  Set<String> widgetBoundFields = const {},
  Set<String> collectionFields = const {},
  Map<String, Set<String>> classCollectionFields = const {},
  Map<String, Map<String, Set<String>>> classRegistryOrigins = const {},
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins = const {},
  Set<String> classRegistryShadowedNames = const {},
  Map<String, Set<String>> classQueryNames = const {},
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins = const {},
  Set<String> classQueryNamesShadowedNames = const {},
}) {
  final visitor = _ValueRewriteVisitor(
    reactiveFields,
    queryNames,
    currentMember,
    classRegistry,
    environmentFields,
    widgetBoundFields,
    collectionFields,
    classCollectionFields,
    classRegistryOrigins,
    classCollectionFieldsOrigins,
    classRegistryShadowedNames,
    classQueryNames,
    classQueryNamesOrigins,
    classQueryNamesShadowedNames,
  );
  node.accept(visitor);
  return ValueRewriteResult(
    visitor.edits,
    visitor.trackedReadNamesByOffset,
    visitor.trackedReadNames,
    visitor.trackedQueryNames,
    visitor.trackedCrossClassReadNames,
    visitor.selfCycleFound,
  );
}

/// Emits a non-annotated user [method] with the `.value` rewrite applied to
/// its body — bare `SimpleIdentifier` reads of [reactiveFields] (same-class)
/// plus the cross-class single-level slice from [classRegistry] (parameter-
/// receiver shape) and [environmentFields] (env-injected receiver shape) in
/// one AST walk. [collectionFields] and [classCollectionFields] suppress
/// `.value` insertion for collection-typed reactive fields (`ListSignal` /
/// `SetSignal` / `MapSignal`) on the chain-access and bare-read paths.
///
/// Used by `plain_class_rewriter` for user methods on plain classes and by
/// `state_class_rewriter` for user methods on `State<X>` subclasses. The two
/// rewriters share this helper so the same `setTempUnit(unit) => tempUnit =
/// unit` → `tempUnit.value = unit` rewrite applies consistently regardless
/// of class kind.
String rewriteUserMethod(
  MethodDeclaration method,
  Set<String> reactiveFields,
  Map<String, Set<String>> classRegistry,
  String source, {
  Map<String, String> environmentFields = const {},
  Set<String> collectionFields = const {},
  Map<String, Set<String>> classCollectionFields = const {},
  Map<String, Map<String, Set<String>>> classRegistryOrigins = const {},
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins = const {},
  Set<String> classRegistryShadowedNames = const {},
}) {
  final result = collectValueEdits(
    method,
    reactiveFields,
    source,
    classRegistry: classRegistry,
    environmentFields: environmentFields,
    collectionFields: collectionFields,
    classCollectionFields: classCollectionFields,
    classRegistryOrigins: classRegistryOrigins,
    classCollectionFieldsOrigins: classCollectionFieldsOrigins,
    classRegistryShadowedNames: classRegistryShadowedNames,
  );
  return applyEditsToRange(
    source.substring(method.offset, method.end),
    result.edits,
    method.offset,
  );
}

/// Applies offset-based [edits] (with absolute file offsets) to [text] whose
/// original file offset begins at [baseOffset]. Returns the rewritten string.
///
/// Edits are sorted reverse-by-offset so earlier offsets stay stable while
/// each splice executes. Empty [edits] short-circuits without allocating.
String applyEditsToRange(String text, List<ValueEdit> edits, int baseOffset) {
  if (edits.isEmpty) return text;
  final sorted = [...edits]..sort((a, b) => b.offset.compareTo(a.offset));
  var result = text;
  for (final e in sorted) {
    final start = e.offset - baseOffset;
    final end = e.end - baseOffset;
    result = result.substring(0, start) + e.replacement + result.substring(end);
  }
  return result;
}

/// The `untracked` identifier exposed by `solid_annotations` — both the
/// `UntrackedExtension` getter (`field.untracked`) and the top-level function
/// (`untracked(() => ...)`). Must stay in sync with those declarations.
const String _untrackedName = 'untracked';

/// Name of the runtime opt-out getter on `ReadableSignal<T>` from
/// `flutter_solidart`. Reading via this getter never subscribes the
/// surrounding reactive context.
const String _untrackedValueGetterName = 'untrackedValue';

/// Name of the runtime opt-out accessor on `Resource<T>` from
/// `flutter_solidart`. Reading via this getter returns the current
/// `ResourceState<T>` without registering a subscription on the surrounding
/// tracking context.
const String _untrackedStateGetterName = 'untrackedState';

/// The `previousState` getter `solid_annotations` exposes on the
/// `RefreshFuture<T>`/`RefreshStream<T>` query tear-off
/// (`<query>.previousState`). After lowering this resolves directly to
/// `Resource.previousState`, which IS reactive at the signal level
/// (`ReadSignal.previousValue` reports observed) — so a bare
/// `<query>.previousState` read (same-class) or
/// `<receiver>.<queryName>.previousState` read (cross-instance) is a
/// tracked read for `SignalBuilder` placement, mirroring
/// [_trackedSignalApiGetters]'s `.hasValue` / `.previousValue` treatment of
/// a `@SolidState` field. Query counterpart of [_untrackedStateGetterName];
/// must NOT be confused with `<query>.refresh`, which stays untracked (an
/// action, not a reactive read).
const String _queryPreviousStateGetterName = 'previousState';

/// `SignalBase<T>` getter names that take a reactive receiver as-is, so a
/// bare tracked-field access followed by any of them must skip the `.value`
/// append. A type-driven rewriter would derive this from the resolved
/// `staticType` of the access; in name-set mode we enumerate.
const Set<String> _signalApiGetters = {'value', 'hasValue', 'previousValue'};

/// Subset of [_signalApiGetters] whose access counts as a tracked read for
/// SignalBuilder placement. `.value` is excluded — by convention, an
/// explicit `.value` read is the user opting out of the auto-tracking flow,
/// while `.hasValue` / `.previousValue` have no bare equivalent and must be
/// tracked to keep the enclosing widget subtree reactive to signal updates.
const Set<String> _trackedSignalApiGetters = {'hasValue', 'previousValue'};

/// Result of [_ValueRewriteVisitor._resolveReceiverType]: a cross-class
/// receiver's simple type `name`, plus the declaring library's `libraryUri`
/// — normalized via [_normalizeLibraryUri] — ONLY when a real resolved
/// `staticType` (tier 1) backed the answer. `libraryUri == null` means the
/// name came from an AST-only fallback (tiers 2-4) and therefore carries no
/// proof of which same-named class it refers to; see
/// [_ValueRewriteVisitor._fieldsForCrossClassName] (issue #110).
typedef _ReceiverType = ({String name, String? libraryUri});

/// Normalizes a resolved `LibraryElement.uri` into the same string form
/// `builder.dart`'s `_registerWantedClassesFrom` stores as a cross-class
/// registry entry's origin — `package:<pkg>/<lib-relative-path>`.
///
/// The two sides start from different vocabularies (issue #110 design
/// note). A resolved element from another package (Flutter,
/// flutter_solidart, a published dependency) already reports a `package:`
/// URI, which matches the registry's format outright — returned unchanged.
/// A resolved element from THIS package's own `source/` tree — the shape
/// every cross-file `@SolidState` class this generator processes takes —
/// reports an `asset:<pkg>/source/<rel>` URI instead: `build_resolvers`
/// resolves the file at its PRE-transformation `source/` location, and
/// `source/` is never a real `lib/` directory, so the analyzer can't mint a
/// `package:` URI for it (verified empirically against this repo's own
/// `testBuilder` harness). Both sides name the exact same file; this
/// function rewrites the `asset:` form into the `package:` form — stripping
/// the `source/` segment, mirroring `builder.dart`'s own
/// `_sourceToLibAsset` — so the comparison in [_ValueRewriteVisitor.
/// _fieldsForCrossClassName] is apples-to-apples. Returns `null` for any
/// other shape (`dart:`, `file:`, or an `asset:` URI outside `source/`, none
/// of which the registry ever produces an origin for) — a `null` result can
/// never equal a recorded origin key, so it safely falls through to "no
/// match" rather than guessing.
String? _normalizeLibraryUri(Uri uri) {
  if (uri.scheme == 'package') return uri.toString();
  if (uri.scheme != 'asset') return null;
  final segments = uri.pathSegments;
  if (segments.length < 3 || segments[1] != 'source') return null;
  final package = segments.first;
  final relativePath = segments.skip(2).join('/');
  return 'package:$package/$relativePath';
}

/// AST visitor that accumulates [ValueEdit]s for reactive-field identifiers.
///
/// Scope tracking is name-based: a local variable, parameter, or function
/// declaration whose name collides with a reactive field suppresses the
/// rewrite inside its enclosing block. This matches Dart's natural
/// shadowing rule (an inner declaration named `counter` resolves all
/// subsequent `counter` references in scope to the local, regardless of
/// type), so a resolved-AST upgrade would add no functional change here —
/// the name-based check IS the language semantic.
class _ValueRewriteVisitor extends RecursiveAstVisitor<void> {
  _ValueRewriteVisitor(
    this._reactiveFields,
    this._queryNames,
    this._currentMember,
    this._classRegistry,
    this._environmentFields,
    this._widgetBoundFields,
    this._collectionFields,
    this._classCollectionFields,
    this._classRegistryOrigins,
    this._classCollectionFieldsOrigins,
    this._classRegistryShadowedNames,
    this._classQueryNames,
    this._classQueryNamesOrigins,
    this._classQueryNamesShadowedNames,
  );

  final Set<String> _reactiveFields;

  /// Per-class set of `@SolidQuery` method names. Drives query-call detection
  /// in any reactive body: build → SignalBuilder placement; query / effect /
  /// state-getter → `Resource.source:` / Effect / Computed wiring. May
  /// include [_currentMember]; the visitor flags a self-cycle rather than
  /// wiring it as a tracked dep.
  final Set<String> _queryNames;

  /// Name of the enclosing `@SolidQuery` method when the body being walked is
  /// itself a query body; `null` for build / effect / state-getter callers.
  /// A zero-arg call whose target name matches sets [selfCycleFound] instead
  /// of contributing to the tracked-name lists, so the reader can surface a
  /// self-cycle error without re-walking the body.
  final String? _currentMember;

  /// Cross-class reactivity map (class name → reactive field/getter names).
  /// Drives the single-level cross-class rewrite in
  /// [visitPrefixedIdentifier]. Empty map → cross-class branch no-ops.
  final Map<String, Set<String>> _classRegistry;

  /// Host-class `@SolidEnvironment` field map (`fieldName -> typeText`).
  /// When the prefix of a `<id>.<reactiveField>` chain is not a method
  /// parameter but matches an env-field name on the enclosing class, the
  /// env field's declared type is looked up in [_classRegistry] for the
  /// cross-class `.value` append. Empty map → env-field branch no-ops; the
  /// parameter-receiver behavior is unchanged.
  final Map<String, String> _environmentFields;

  /// Names of widget-bound non-`@SolidState` fields on the host class.
  /// After the StatelessWidget→StatefulWidget split, the body being
  /// rewritten lives on the State class while these fields stay on the
  /// widget instance, so a bare reference (`label`) must be prefixed with
  /// `widget.` for the State to see them as `widget.label`. Disjoint from
  /// `_reactiveFields` by construction (the caller subtracts the reactive
  /// set before passing). Empty for callers that do NOT move bodies between
  /// scopes (state-class rewriter, plain-class rewriter).
  final Set<String> _widgetBoundFields;

  /// Same-class `@SolidState` field names whose emitted constructor is a
  /// collection signal (`ListSignal<T>` / `SetSignal<T>` / `MapSignal<K, V>`).
  /// Subset of [_reactiveFields]. Collection signals expose the full
  /// `ListMixin` / `SetMixin` / `MapMixin` API directly on the signal, so
  /// chain accesses (`xs.length`, `xs.add(x)`, `xs[i]`) and bare-read
  /// references (`final l = xs;`) do NOT receive a `.value` append. Writes
  /// (`xs = newList`) still rewrite to `xs.value = newList` via the Signal
  /// setter — that path is shared with scalar fields.
  final Set<String> _collectionFields;

  /// Cross-class collection-field map (class name → collection field names).
  /// Subset of [_classRegistry]. Drives the same no-`.value`-on-chain rule as
  /// [_collectionFields] but for `<envField>.<collectionField>` shapes —
  /// `controller.todos.length` resolves to `ListSignal<Todo>.length` and
  /// must NOT receive a `.value` append between `todos` and `length`.
  final Map<String, Set<String>> _classCollectionFields;

  /// Per-name origin-qualified counterpart of [_classRegistry] (issue #110)
  /// — `name -> originUri -> reactive field/getter names` — populated by
  /// `builder.dart` ONLY for a name it flagged in
  /// [_classRegistryShadowedNames]. Consulted by [_fieldsForCrossClassName]
  /// instead of [_classRegistry] for exactly those flagged names; empty
  /// (the default) whenever the caller has no origin data to thread
  /// through, in which case a flagged name simply never resolves (safe:
  /// [_classRegistry] itself holds no entry for it either — see
  /// `builder.dart::_populateCrossFileTypes`'s finalize pass).
  final Map<String, Map<String, Set<String>>> _classRegistryOrigins;

  /// Per-name origin-qualified counterpart of [_classCollectionFields],
  /// parallel to [_classRegistryOrigins].
  final Map<String, Map<String, Set<String>>> _classCollectionFieldsOrigins;

  /// Names `builder.dart` could not resolve unambiguously by simple name
  /// alone (issue #110) — either two-plus distinct cross-file classes share
  /// the name, or a cross-file class's name is ALSO declared locally in the
  /// file being rewritten. [_fieldsForCrossClassName] routes these names
  /// through [_classRegistryOrigins] / [_classCollectionFieldsOrigins] with
  /// a mandatory tier-1 library-URI match instead of the flat maps.
  final Set<String> _classRegistryShadowedNames;

  /// Cross-class `@SolidQuery` name map (class name → `@SolidQuery` method
  /// names) — the query counterpart of [_classRegistry]. Drives
  /// [_isCrossClassQueryCall]; empty map → the cross-instance query branch
  /// no-ops.
  final Map<String, Set<String>> _classQueryNames;

  /// Per-name origin-qualified counterpart of [_classQueryNames] (issue
  /// #110) — `name -> originUri -> query method names` — populated by
  /// `builder.dart` ONLY for a name it flagged in
  /// [_classQueryNamesShadowedNames]. Mirrors [_classRegistryOrigins].
  final Map<String, Map<String, Set<String>>> _classQueryNamesOrigins;

  /// Names `builder.dart` could not resolve unambiguously by simple name
  /// alone for [_classQueryNames] (issue #110) — mirrors
  /// [_classRegistryShadowedNames]. [_queryNamesForCrossClassName] routes
  /// these names through [_classQueryNamesOrigins] with a mandatory tier-1
  /// library-URI match instead of the flat [_classQueryNames].
  final Set<String> _classQueryNamesShadowedNames;

  final List<ValueEdit> edits = [];

  /// Tracked-read offsets keyed by signal name — drives the placement
  /// pass's same-signal collapse. See [ValueRewriteResult] for the full
  /// contract; the map's `.keys` iteration order is also the canonical
  /// tracked-offset ordering downstream consumers expect.
  final Map<int, String> trackedReadNamesByOffset = {};

  /// Reactive-field/getter identifier names read in tracked position, in
  /// source-first-appearance order. Deduplicated via [_recordTrackedReadName].
  /// Excludes query-call invocations (those go to [trackedQueryNames]).
  final List<String> trackedReadNames = [];

  /// Same-class `@SolidQuery` method names invoked as tracked zero-arg
  /// calls. Source-first-appearance order, deduplicated.
  final List<String> trackedQueryNames = [];

  /// Cross-class `@SolidState` reads in tracked position —
  /// `<envField>.<signalName>` pairs where the prefix is an
  /// `@SolidEnvironment` field on the enclosing class and the property is a
  /// `@SolidState` field/getter on the env-field's declared type.
  /// Source-first-appearance order, deduplicated by pair.
  final List<CrossClassDep> trackedCrossClassReadNames = [];

  /// Set true when the body invokes [_currentMember] as a zero-arg tracked
  /// call — a self-cycle. The reader checks this and throws.
  bool selfCycleFound = false;

  /// Stack of shadowed-name sets, one frame per enclosing block / function.
  final List<Set<String>> _scopeStack = [<String>{}];

  /// Depth of untracked contexts; >0 means every read visited here is
  /// treated as untracked. Nested `on*` callbacks (Section 6.2) accumulate.
  int _untrackedDepth = 0;

  bool _isShadowed(String name) =>
      _scopeStack.any((frame) => frame.contains(name));

  /// True if [name] is a reactive field reference that the rewriter should
  /// rewrite at this site — known reactive name AND not shadowed by a local.
  bool _isTrackedField(String name) =>
      _reactiveFields.contains(name) && !_isShadowed(name);

  @override
  void visitBlock(Block node) {
    _scopeStack.add(<String>{});
    super.visitBlock(node);
    _scopeStack.removeLast();
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final untracked = _isUntrackedCallback(node);
    _scopeStack.add(<String>{});
    final params = node.parameters?.parameters ?? const <FormalParameter>[];
    for (final param in params) {
      final id = param.name?.lexeme;
      if (id != null) _scopeStack.last.add(id);
    }
    if (untracked) _untrackedDepth++;
    super.visitFunctionExpression(node);
    if (untracked) _untrackedDepth--;
    _scopeStack.removeLast();
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _scopeStack.last.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `untracked(() => ...)` passes through verbatim and resolves to
    // flutter_solidart's `untracked` at runtime; the depth bump suppresses
    // dependency recording for inner reads, as for `on*` callbacks in
    // [visitFunctionExpression]. The `!_isShadowed` guard mirrors the
    // query-call branch below: a local/parameter named `untracked` is the
    // user's own function, not the opt-out. (The `<field>.untracked` getter is
    // handled separately in [visitPrefixedIdentifier].)
    if (node.target == null &&
        node.methodName.name == _untrackedName &&
        !_isShadowed(_untrackedName)) {
      _untrackedDepth++;
      super.visitMethodInvocation(node);
      _untrackedDepth--;
      return;
    }
    // A `@SolidQuery` body that calls itself is rejected at codegen — flag
    // here so the reader can throw without walking the body a second time.
    if (_isQueryShape(node) && node.methodName.name == _currentMember) {
      selfCycleFound = true;
    } else if (_isQueryShape(node) &&
        _queryNames.contains(node.methodName.name) &&
        !_isUntrackedQueryCall(node) &&
        _untrackedDepth == 0) {
      // A zero-arg call to a same-class `@SolidQuery` is a tracked read.
      // Inside `build()` the offset drives SignalBuilder placement; inside
      // any other reactive body the name drives `Resource.source:` / Effect
      // / Computed dep wiring. No source edit is emitted — `fetchData()`
      // survives byte-identical because the lowered field is a `Resource<T>`
      // whose `call()` returns `ResourceState<T>` and the trailing chain
      // resolves to upstream extensions.
      _recordTrackedRead(node.offset, node.methodName.name);
      _recordTrackedQueryName(node.methodName.name);
    } else if (_untrackedDepth == 0 && _isCrossClassQueryCall(node)) {
      // Cross-instance `<receiver>.<queryName>()` — the query counterpart of
      // [_maybeRewriteCrossClass]'s `<receiver>.<reactiveField>` shape. NO
      // source edit: the call is byte-identical because it lowers to
      // `Resource<T>.call() -> ResourceState<T>` and the trailing
      // `.isLoading`/`.asReady`/`.asError` chain resolves through upstream
      // `flutter_solidart` extensions unchanged. Only the offset is recorded
      // so SignalBuilder placement wraps the enclosing widget subtree.
      _recordTrackedRead(node.offset, node.methodName.name);
    }
    super.visitMethodInvocation(node);
  }

  /// True if [node] is a cross-instance `<receiver>.<queryName>()` call: a
  /// zero-arg `MethodInvocation` with a target (never bare — that shape is
  /// [_isQueryShape]'s same-class branch above), not shadowed when the
  /// target is a bare identifier, whose receiver's declared type — resolved
  /// the same way [_maybeRewriteCrossClass] resolves a `<receiver>.<field>`
  /// prefix — names a class in [_queryNamesForCrossClassName] whose set
  /// contains the called method's name.
  bool _isCrossClassQueryCall(MethodInvocation node) {
    final target = node.target;
    if (target == null) return false;
    if (node.argumentList.arguments.isNotEmpty) return false;
    if (target is SimpleIdentifier && _isShadowed(target.name)) return false;
    final receiverType = _resolveReceiverType(target);
    final declaredTypeName =
        receiverType?.name ??
        (target is SimpleIdentifier ? _environmentFields[target.name] : null);
    if (declaredTypeName == null) return false;
    final queryNamesOfType = _queryNamesForCrossClassName(
      declaredTypeName,
      receiverType?.libraryUri,
    );
    return queryNamesOfType?.contains(node.methodName.name) ?? false;
  }

  /// Query-name resolver for [declaredTypeName] — the query counterpart of
  /// [_fieldsForCrossClassName]. Same safety invariant (issue #110): a name
  /// NOT in [_classQueryNamesShadowedNames] is served straight from the flat
  /// [_classQueryNames]; a FLAGGED name only resolves when [libraryUri] is
  /// non-null (tier 1 — a real resolved `staticType`) AND matches one of the
  /// origins [_classQueryNamesOrigins] recorded for [declaredTypeName]. See
  /// [_fieldsForCrossClassName]'s doc comment for the full invariant this
  /// mirrors.
  Set<String>? _queryNamesForCrossClassName(
    String declaredTypeName,
    String? libraryUri,
  ) {
    if (!_classQueryNamesShadowedNames.contains(declaredTypeName)) {
      return _classQueryNames[declaredTypeName];
    }
    if (libraryUri == null) return null;
    return _classQueryNamesOrigins[declaredTypeName]?[libraryUri];
  }

  /// True if [node] is a zero-arg `MethodInvocation` with a bare
  /// `SimpleIdentifier` target whose name is not shadowed — the structural
  /// shape of every detection site that consults [_queryNames] or
  /// [_currentMember]. Callers add their own name-set / opt-out checks on
  /// top.
  bool _isQueryShape(MethodInvocation node) =>
      node.target == null &&
      node.argumentList.arguments.isEmpty &&
      !_isShadowed(node.methodName.name);

  /// True if [node] is the target of a `<query>().untracked` `PropertyAccess`
  /// — i.e. the user opted out of tracking. The surrounding
  /// `visitPropertyAccess` rewrites the whole sub-expression to
  /// `<query>.untrackedState`, so the inner call must NOT count as a tracked
  /// read for SignalBuilder placement OR `source:` wiring.
  bool _isUntrackedQueryCall(MethodInvocation node) {
    final parent = node.parent;
    return parent is PropertyAccess &&
        parent.target == node &&
        parent.propertyName.name == _untrackedName &&
        _queryNames.contains(node.methodName.name);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Rewrite `<queryName>().untracked` to `<queryName>.untrackedState` (the
    // runtime non-subscribing accessor on `Resource<T>`). The whole chain
    // (inner MethodInvocation + outer PropertyAccess) is replaced; the
    // trailing chain after `.untracked` — `.value`, `.when`, `.isReady`,
    // etc. — is preserved verbatim because
    // the edit ends at `node.end` (the property name), not beyond.
    final target = node.target;
    if (node.propertyName.name == _untrackedName &&
        target is MethodInvocation &&
        _isQueryShape(target) &&
        _queryNames.contains(target.methodName.name)) {
      edits.add(
        ValueEdit(
          node.offset,
          node.end,
          '${target.methodName.name}.$_untrackedStateGetterName',
        ),
      );
      // Skip super: descending would let visitMethodInvocation re-process
      // the inner `<queryName>()` which we have already accounted for via
      // [_isUntrackedQueryCall].
      return;
    }
    // Cross-instance `<receiver>.<queryName>.previousState` — the
    // PropertyAccess counterpart of [visitPrefixedIdentifier]'s same-class
    // branch. A tracked read with NO source edit.
    if (node.propertyName.name == _queryPreviousStateGetterName &&
        _untrackedDepth == 0) {
      _maybeRecordCrossClassPreviousState(node);
    }
    // Multi-level cross-class chain rewrite. `a.b.c.d` parses as
    // PropertyAccess(target=PropertyAccess(target=PrefixedIdentifier(a, b),
    // property=c), property=d); `getController().field` parses as
    // PropertyAccess(target=MethodInvocation, property=field). Both shapes
    // are caught here by resolving the receiver's `staticType` via
    // [_resolveReceiverType] and looking up the property name in
    // [_classRegistry]. PrefixedIdentifier (the single-level `a.b` shape)
    // is handled by [_maybeRewriteCrossClass] above so the two paths don't
    // overlap.
    // A name issue #110 flagged as ambiguous is stripped from `_classRegistry`
    // (see `builder.dart::_populateCrossFileTypes`'s finalize pass) — so an
    // otherwise-`_classRegistry`-empty file whose ONLY cross-class candidate
    // is such a flagged name would wrongly skip this branch entirely without
    // also checking `_classRegistryShadowedNames`.
    if ((_classRegistry.isNotEmpty || _classRegistryShadowedNames.isNotEmpty) &&
        target != null) {
      _maybeRewriteCrossClassPropertyAccess(node);
    }
    super.visitPropertyAccess(node);
  }

  /// Cross-class rewrite for PropertyAccess shapes: chains > 2 levels
  /// (`a.b.c.d`) and non-SimpleIdentifier receivers (`getController().field`,
  /// `(expr).field`). Only fires when [Expression.staticType] on the
  /// receiver resolves to an [InterfaceType] — there's no parsed-AST
  /// fallback for these shapes, so an unresolved type means no rewrite.
  ///
  /// Limitation: this path does NOT contribute to
  /// `trackedCrossClassReadNames` (the input to `Resource.source:`
  /// Record-Computed synthesis on `@SolidQuery` bodies). That tracking
  /// requires identifying the chain's root env-field — a separate walk
  /// not implemented here. A user writing `controller.session.user.name`
  /// inside a `@SolidQuery` body gets the value rewrite for body
  /// correctness, but the Resource won't include the chain in its
  /// multi-dep `source:` Record. Single-level env reads still go through
  /// [_maybeRewriteCrossClass] and ARE tracked there.
  void _maybeRewriteCrossClassPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target == null) return;
    if (_isAccessOnSignalApi(node.propertyName, _signalApiGetters)) return;
    // Outer-chain Signal API guard: same as the single-level branch.
    final outerParent = node.parent;
    if (outerParent is PropertyAccess &&
        outerParent.target == node &&
        _signalApiGetters.contains(outerParent.propertyName.name)) {
      if (_trackedSignalApiGetters.contains(outerParent.propertyName.name) &&
          _untrackedDepth == 0) {
        _recordTrackedRead(node.offset, node.propertyName.name);
      }
      return;
    }
    final receiverType = _resolveReceiverType(target);
    if (receiverType == null) return;
    final resolved = _fieldsForCrossClassName(
      receiverType.name,
      receiverType.libraryUri,
    );
    if (resolved == null) return;
    final fieldsOfType = resolved.fields;
    if (!fieldsOfType.contains(node.propertyName.name)) return;
    final collectionFieldsOfType = resolved.collectionFields;
    final isCollection =
        collectionFieldsOfType != null &&
        collectionFieldsOfType.contains(node.propertyName.name);
    final isChainPrefix = _isAnyChainTarget(node);
    if (!isCollection || !isChainPrefix) {
      edits.add(ValueEdit(node.end, node.end, '.value'));
    }
    if (_untrackedDepth == 0) {
      _recordTrackedRead(node.offset, node.propertyName.name);
    }
  }

  /// Cross-instance `<receiver>.<queryName>.previousState` detector — the
  /// query counterpart of [_isCrossClassQueryCall], but for the
  /// PropertyAccess tear-off shape (`.previousState`) instead of the
  /// MethodInvocation call shape (`()`). [node] is the outer `.previousState`
  /// PropertyAccess; its target must be the `<receiver>.<queryName>`
  /// PrefixedIdentifier — the only chain shape recognized here, mirroring
  /// the single-level scope [_maybeRewriteCrossClass] keeps for
  /// `@SolidState` fields. Records the tracked-read offset with NO source
  /// edit when the target prefix's resolved declared type names a class
  /// whose query set (via [_queryNamesForCrossClassName]) contains the
  /// target identifier's name.
  void _maybeRecordCrossClassPreviousState(PropertyAccess node) {
    final target = node.target;
    if (target is! PrefixedIdentifier) return;
    if (_isShadowed(target.prefix.name)) return;
    final receiverType = _resolveReceiverType(target.prefix);
    final declaredTypeName =
        receiverType?.name ?? _environmentFields[target.prefix.name];
    if (declaredTypeName == null) return;
    final queryNamesOfType = _queryNamesForCrossClassName(
      declaredTypeName,
      receiverType?.libraryUri,
    );
    if (queryNamesOfType == null ||
        !queryNamesOfType.contains(target.identifier.name)) {
      return;
    }
    _recordTrackedRead(node.offset, target.identifier.name);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Rewrite `<reactiveField>.untracked` to `<field>.untrackedValue` (the
    // runtime primitive on `ReadableSignal<T>`). The offset is intentionally
    // NOT recorded as a tracked read and `_untrackedDepth` is intentionally
    // not consulted — an `.untracked` read must never subscribe, regardless
    // of surrounding context.
    if (node.identifier.name == _untrackedName &&
        _isTrackedField(node.prefix.name)) {
      edits.add(
        ValueEdit(
          node.offset,
          node.end,
          '${node.prefix.name}.$_untrackedValueGetterName',
        ),
      );
      // Skip super: descending would let visitSimpleIdentifier append `.value`
      // to the prefix, corrupting the replacement just emitted.
      return;
    }
    // Same-class `<queryName>.previousState` — a tracked read with NO
    // source edit (see [_queryPreviousStateGetterName]). Must be an exact
    // name match against `previousState`, never `refresh` — the tear-off
    // shape is otherwise identical (`<queryName>.<getterOrMethod>`) and
    // `refresh` must stay untracked.
    if (node.identifier.name == _queryPreviousStateGetterName &&
        _queryNames.contains(node.prefix.name) &&
        !_isShadowed(node.prefix.name) &&
        _untrackedDepth == 0) {
      _recordTrackedRead(node.offset, node.prefix.name);
    }
    // Cross-class single-level slice: if the prefix is a `SimpleIdentifier`
    // resolving to either a method parameter OR a host-class
    // `@SolidEnvironment` field whose declared type names a class in
    // [_classRegistry] AND the suffix matches a reactive field on that
    // class, append `.value`. Full type-driven chain support (`a.b.c.d`)
    // still requires the resolved-AST migration. We keep this branch
    // conservative — only single `<receiver>.<field>` shapes — so the
    // existing same-class goldens stay byte-identical.
    // See the matching comment in [visitPropertyAccess]: a name issue #110
    // flagged as ambiguous is stripped from `_classRegistry`, so this guard
    // must also open the door via `_classRegistryShadowedNames`.
    if (_classRegistry.isNotEmpty || _classRegistryShadowedNames.isNotEmpty) {
      _maybeRewriteCrossClass(node);
    }
    super.visitPrefixedIdentifier(node);
  }

  /// Single-level `<receiver>.<reactiveField>` cross-class rewrite — the
  /// shipped slice of the chain-aware rule. The receiver type resolves via
  /// [_resolveReceiverType] (parameter / local / property-of-resolved-type)
  /// then [_environmentFields] (`@SolidEnvironment` host-class field);
  /// parameter wins because method parameters shadow host-class fields in
  /// Dart and are not tracked by [_isShadowed] (which covers only
  /// `visitFunctionExpression` and block-local declarations), so the lookup
  /// ORDER carries the parameter-vs-field shadowing semantics here.
  ///
  /// Collection-field branch: if the resolved field is in
  /// [_classCollectionFields] for its receiver type AND the whole
  /// `<receiver>.<field>` shape is used as the prefix of a longer chain
  /// (parent is `PropertyAccess` / `MethodInvocation` / `IndexExpression` /
  /// `PrefixedIdentifier`), the rewrite skips the `.value` append — the
  /// trailing `.length` / `.where(…)` / `[i]` resolves through the
  /// collection-signal mixin directly. For a bare cross-class collection
  /// read (used as the whole return value, argument, or RHS), `.value` is
  /// inserted so the reactive context subscribes — without it, the
  /// returned `ListSignal` reference is identity-stable and a `Computed`
  /// body would never invalidate. Tracking always fires so the surrounding
  /// widget subtree is wrapped in `SignalBuilder`.
  void _maybeRewriteCrossClass(PrefixedIdentifier node) {
    if (_isShadowed(node.prefix.name)) return;
    if (_isAccessOnSignalApi(node.identifier, _signalApiGetters)) return;
    // Outer-chain Signal API guard: a `<receiver>.<reactiveField>.<getter>`
    // chain where `<getter>` is `.value` / `.hasValue` / `.previousValue`
    // must pass through verbatim — inserting `.value` between the field and
    // the getter would route the call through the unboxed payload type.
    // `.hasValue` / `.previousValue` chains are reactive reads and still
    // record an offset so SignalBuilder placement wraps the surrounding
    // subtree (see [_trackedSignalApiGetters]).
    final outerParent = node.parent;
    final isEnvReceiver = _environmentFields.containsKey(node.prefix.name);
    if (outerParent is PropertyAccess &&
        outerParent.target == node &&
        _signalApiGetters.contains(outerParent.propertyName.name)) {
      if (_trackedSignalApiGetters.contains(outerParent.propertyName.name) &&
          _untrackedDepth == 0) {
        _recordTrackedRead(node.offset, node.identifier.name);
        if (isEnvReceiver) {
          _recordTrackedCrossClassRead(
            node.prefix.name,
            node.identifier.name,
          );
        }
      }
      return;
    }
    final receiverType = _resolveReceiverType(node.prefix);
    final declaredTypeName =
        receiverType?.name ?? _environmentFields[node.prefix.name];
    if (declaredTypeName == null) return;
    final resolved = _fieldsForCrossClassName(
      declaredTypeName,
      receiverType?.libraryUri,
    );
    if (resolved == null) return;
    final fieldsOfType = resolved.fields;
    if (!fieldsOfType.contains(node.identifier.name)) return;
    final collectionFieldsOfType = resolved.collectionFields;
    final isCollection =
        collectionFieldsOfType != null &&
        collectionFieldsOfType.contains(node.identifier.name);
    final isChainPrefix = _isCrossClassChainPrefix(node);
    if (!isCollection || !isChainPrefix) {
      edits.add(ValueEdit(node.end, node.end, '.value'));
    }
    if (_untrackedDepth == 0) {
      _recordTrackedRead(node.offset, node.identifier.name);
      // Cross-class scalar signal reads through an `@SolidEnvironment`
      // receiver feed `Resource.source:` synthesis for enclosing `@SolidQuery`
      // bodies. Collection-typed signals are intentionally excluded: their
      // mutations notify via the mixin's own listeners — a Resource that
      // depends on a ListSignal's contents would need a deeper dep model
      // than the `source:` Signal-reference path can express, and is
      // deferred until a real example exercises it.
      if (isEnvReceiver && !isCollection) {
        _recordTrackedCrossClassRead(
          node.prefix.name,
          node.identifier.name,
        );
      }
    }
  }

  /// True if [node] is the `target` of its parent expression — any of
  /// `PropertyAccess`, `MethodInvocation`, `IndexExpression`, or
  /// `CascadeExpression`. Every chain shape carries its receiver on a
  /// `target` field on the outer node, so checking the parent is the only
  /// way to detect a cascade (whose implicit receiver bypasses a
  /// member-chain on the inner identifier entirely).
  ///
  /// Used by both same-class ([_isChainPrefix]) and cross-class
  /// ([_isCrossClassChainPrefix]) branches.
  static bool _isAnyChainTarget(Expression node) {
    final parent = node.parent;
    if (parent is PropertyAccess && parent.target == node) return true;
    if (parent is MethodInvocation && parent.target == node) return true;
    if (parent is IndexExpression && parent.target == node) return true;
    if (parent is CascadeExpression && parent.target == node) return true;
    return false;
  }

  /// True if [node] (a `<receiver>.<field>` PrefixedIdentifier) is itself
  /// used as the prefix of a longer chain. `PrefixedIdentifier.prefix` is
  /// always a `SimpleIdentifier`, so an `a.b.c` chain parses as
  /// `PropertyAccess(target=PrefixedIdentifier(a, b), property=c)` —
  /// never as nested `PrefixedIdentifier`s. Hence the cross-class case
  /// delegates entirely to [_isAnyChainTarget].
  bool _isCrossClassChainPrefix(PrefixedIdentifier node) =>
      _isAnyChainTarget(node);

  /// Returns the simple type name of [receiver] — using the same four-tier
  /// resolution [_resolveReceiverType] documents — paired with the
  /// declaring library's origin URI ONLY when tier 1 answered (see
  /// [_ReceiverType]).
  ///
  ///  1. **Element-based.** When [Expression.staticType] is a resolved
  ///     [InterfaceType], return its element name AND (issue #110) the
  ///     origin URI of the class's declaring library, normalized via
  ///     [_normalizeLibraryUri] into the same form `builder.dart`'s registry
  ///     origins use. Catches locals (`var c = controller; c.field`),
  ///     method-call receivers (`getController().field`), and parameters
  ///     identically — `staticType` is populated for every expression in
  ///     resolved AST. This is the ONLY tier that can serve a name flagged
  ///     in [_classRegistryShadowedNames] — see [_fieldsForCrossClassName].
  ///  2. **AST fallback (parameters).** When the resolver hasn't run
  ///     (parsed-AST fallback or test sandbox without the necessary SDK),
  ///     resolve [receiver] as a method/function parameter declared with a
  ///     [NamedType] annotation. Function-typed parameters, `var`-typed
  ///     parameters, `FieldFormalParameter`, and `SuperFormalParameter`
  ///     return `null` in this tier — a parameter name match with no
  ///     resolvable type still counts as "matched" and short-circuits tier 3
  ///     (a parameter shadows a same-named field; falling through to the
  ///     field would rewrite the wrong receiver). No library URI is ever
  ///     available here — this tier never has a resolved element to ask.
  ///  3. **AST fallback (instance fields).** When [receiver] is not a
  ///     parameter at all (matched or not), resolve it as a non-static field
  ///     of the enclosing [ClassDeclaration] declared with a [NamedType] —
  ///     the constructor-injected DI shape (`final AuthRepository
  ///     _authRepository;`) most Flutter apps use. Other receiver shapes
  ///     (locals, method-call results) cannot be resolved on parsed AST and
  ///     return `null` — the cross-class rewrite then no-ops, leaving the
  ///     source unchanged.
  ///  4. **AST fallback (`this.<field>`).** When [receiver] is a
  ///     [PropertyAccess] whose target is a [ThisExpression] (`this.field` —
  ///     `this` is a keyword, so this shape can never parse as a
  ///     [PrefixedIdentifier] / tier-2-or-3 [SimpleIdentifier]), resolve
  ///     `field` directly against the same instance-field tier as case 3 —
  ///     skipping the parameter-shadow check entirely. `this.` explicitly
  ///     names a field; that is its purpose, and it must resolve to the
  ///     field even when a same-named parameter is in scope (unlike a bare
  ///     reference, which the parameter legitimately shadows).
  _ReceiverType? _resolveReceiverType(Expression receiver) {
    final type = receiver.staticType;
    if (type is InterfaceType) {
      final elementName = type.element.name;
      if (elementName == null) return null;
      return (
        name: elementName,
        libraryUri: _normalizeLibraryUri(type.element.library.uri),
      );
    }
    if (receiver is SimpleIdentifier) {
      final name = _isParameterName(receiver)
          ? _resolveParameterTypeNameFromAst(receiver)
          : _resolveInstanceFieldTypeNameFromAst(receiver);
      return name == null ? null : (name: name, libraryUri: null);
    }
    if (receiver is PropertyAccess && receiver.target is ThisExpression) {
      final name = _resolveInstanceFieldTypeNameByName(
        receiver.propertyName.name,
        receiver,
      );
      return name == null ? null : (name: name, libraryUri: null);
    }
    return null;
  }

  /// Field-set resolver for a `<receiver>.<field>` (or longer chain)
  /// cross-class candidate whose receiver's declared type resolved to
  /// [declaredTypeName], given the receiver's [libraryUri] — non-null ONLY
  /// when [_resolveReceiverType]'s tier 1 (a real resolved `staticType`)
  /// answered the question.
  ///
  /// SAFETY INVARIANT (issue #110): [_classRegistryShadowedNames] contains
  /// EXACTLY the names `builder.dart` could not resolve unambiguously by
  /// simple name alone — two or more distinct cross-file classes sharing
  /// the name, or a cross-file class whose name is ALSO declared locally in
  /// the file being rewritten (the shadowing scenario the issue exists to
  /// fix — previously dropped from the registry entirely, silently losing
  /// the foreign class's reactivity). A name NOT in that set is served
  /// straight from the flat [_classRegistry] / [_classCollectionFields] —
  /// byte-identical to every rewrite this generator already performed
  /// before issue #110, no URI check involved. A FLAGGED name can only
  /// resolve when [libraryUri] is non-null (tier 1) AND matches one of the
  /// origins [_classRegistryOrigins] recorded for [declaredTypeName]: an
  /// AST-only receiver (tiers 2-4, [libraryUri] `null`) or a resolved
  /// receiver whose library matches none of the recorded origins returns
  /// `null` — no rewrite, the same conservative outcome the pre-#110
  /// registry produced for this name (it held no entry for it at all).
  /// Net effect: every rewrite that fired before issue #110 still fires
  /// unchanged; a previously-blocked foreign read can newly fire, but ONLY
  /// through a tier-1 library-URI match — no name-based guess is ever
  /// upgraded into a rewrite without one.
  ({Set<String> fields, Set<String>? collectionFields})?
  _fieldsForCrossClassName(String declaredTypeName, String? libraryUri) {
    if (!_classRegistryShadowedNames.contains(declaredTypeName)) {
      final fields = _classRegistry[declaredTypeName];
      if (fields == null) return null;
      return (
        fields: fields,
        collectionFields: _classCollectionFields[declaredTypeName],
      );
    }
    if (libraryUri == null) return null;
    final fields = _classRegistryOrigins[declaredTypeName]?[libraryUri];
    if (fields == null) return null;
    return (
      fields: fields,
      collectionFields:
          _classCollectionFieldsOrigins[declaredTypeName]?[libraryUri],
    );
  }

  /// True if [prefix] names a parameter of the nearest enclosing
  /// [MethodDeclaration] / [FunctionExpression], regardless of whether that
  /// parameter's type is resolvable. Gates the tier-3 instance-field fallback
  /// in [_resolveReceiverType]: Dart scoping always prefers a parameter
  /// over a same-named field, so an unresolvable parameter type must produce
  /// "no rewrite" rather than silently resolving through the shadowed field.
  bool _isParameterName(SimpleIdentifier prefix) {
    final params =
        prefix
            .thisOrAncestorOfType<MethodDeclaration>()
            ?.parameters
            ?.parameters ??
        prefix
            .thisOrAncestorOfType<FunctionExpression>()
            ?.parameters
            ?.parameters;
    if (params == null) return false;
    for (final param in params) {
      final inner = param is DefaultFormalParameter ? param.parameter : param;
      if (inner.name?.lexeme == prefix.name) return true;
    }
    return false;
  }

  /// AST-only parameter resolver — tier 2 of [_resolveReceiverType].
  /// Walks the prefix's enclosing [MethodDeclaration] / [FunctionExpression]
  /// for a matching [SimpleFormalParameter] and returns the declared
  /// [NamedType]'s lexeme.
  String? _resolveParameterTypeNameFromAst(SimpleIdentifier prefix) {
    final params =
        prefix
            .thisOrAncestorOfType<MethodDeclaration>()
            ?.parameters
            ?.parameters ??
        prefix
            .thisOrAncestorOfType<FunctionExpression>()
            ?.parameters
            ?.parameters;
    if (params == null) return null;
    for (final param in params) {
      final inner = param is DefaultFormalParameter ? param.parameter : param;
      if (inner.name?.lexeme != prefix.name) continue;
      if (inner is SimpleFormalParameter) {
        final type = inner.type;
        if (type is NamedType) return type.name.lexeme;
      }
      return null;
    }
    return null;
  }

  /// AST-only instance-field resolver — tier 3 of [_resolveReceiverType].
  /// Covers the most common Flutter DI shape — a constructor-injected field
  /// (`final AuthRepository _authRepository;`) — that has no parameter
  /// counterpart. Callers gate this tier on [_isParameterName] returning
  /// `false` so a parameter never gets shadowed by a same-named field.
  String? _resolveInstanceFieldTypeNameFromAst(SimpleIdentifier prefix) =>
      _resolveInstanceFieldTypeNameByName(prefix.name, prefix);

  /// Shared implementation of [_resolveInstanceFieldTypeNameFromAst] (tier 3)
  /// and the `this.<field>` branch (tier 4) of [_resolveReceiverType].
  /// Walks [anchor]'s enclosing [ClassDeclaration] for a matching non-static
  /// [FieldDeclaration] named [name] and returns the declared [NamedType]'s
  /// lexeme. Returns `null` when no field on the enclosing class matches
  /// [name] at all.
  ///
  /// When a matching field IS found but is declared with no type annotation
  /// (`final _service;` — infers `dynamic` under Dart's own rules, which
  /// does NOT consult a same-named constructor parameter's explicit type),
  /// falls back to [_resolveFieldTypeFromConstructorParams] (issue #106
  /// residual gap survey, GAP 4) rather than returning `null` outright.
  String? _resolveInstanceFieldTypeNameByName(String name, AstNode anchor) {
    final classDecl = anchor.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return null;
    var untypedFieldFound = false;
    for (final member in classDecl.members) {
      if (member is! FieldDeclaration) continue;
      if (member.isStatic) continue;
      for (final variable in member.fields.variables) {
        if (variable.name.lexeme != name) continue;
        final type = member.fields.type;
        if (type is NamedType) return type.name.lexeme;
        untypedFieldFound = true;
      }
    }
    if (!untypedFieldFound) return null;
    return _resolveFieldTypeFromConstructorParams(classDecl, name);
  }

  /// Fallback for an untyped instance field (`final _service;` — infers
  /// `dynamic`): recovers the real type from a constructor that initializes
  /// it, covering two simple, unambiguous shapes:
  ///
  ///  1. A field-formal parameter with an explicit type
  ///     (`Foo(AuthService this._service)`).
  ///  2. A plain typed parameter assigned to the field in the same
  ///     constructor's initializer list, via a bare-identifier RHS
  ///     (`Foo(AuthService service) : _service = service;`).
  ///
  /// Scans every constructor. If two constructors supply DIFFERENT types for
  /// [fieldName], the result is ambiguous and this bails to `null`
  /// (unresolved) rather than guess — the same "unknown wins over wrong
  /// guess" posture the rest of this file's resolution tiers take.
  String? _resolveFieldTypeFromConstructorParams(
    ClassDeclaration classDecl,
    String fieldName,
  ) {
    String? found;
    for (final member in classDecl.members) {
      if (member is! ConstructorDeclaration) continue;
      final candidate = _fieldTypeFromConstructor(member, fieldName);
      if (candidate == null) continue;
      if (found != null && found != candidate) return null;
      found = candidate;
    }
    return found;
  }

  /// Returns the type [fieldName] resolves to from [ctor]'s field-formal
  /// parameter or initializer-list assignment, or `null` if neither shape
  /// is present. See [_resolveFieldTypeFromConstructorParams] for the two
  /// shapes covered.
  String? _fieldTypeFromConstructor(
    ConstructorDeclaration ctor,
    String fieldName,
  ) {
    for (final param in ctor.parameters.parameters) {
      final inner = param is DefaultFormalParameter ? param.parameter : param;
      if (inner is FieldFormalParameter && inner.name.lexeme == fieldName) {
        final type = inner.type;
        if (type is NamedType) return type.name.lexeme;
      }
    }
    for (final initializer in ctor.initializers) {
      if (initializer is! ConstructorFieldInitializer) continue;
      if (initializer.fieldName.name != fieldName) continue;
      final expr = initializer.expression;
      if (expr is! SimpleIdentifier) continue;
      for (final param in ctor.parameters.parameters) {
        final inner = param is DefaultFormalParameter ? param.parameter : param;
        if (inner is SimpleFormalParameter && inner.name?.lexeme == expr.name) {
          final type = inner.type;
          if (type is NamedType) return type.name.lexeme;
        }
      }
    }
    return null;
  }

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    final expr = node.expression;
    final isShortForm = node.leftBracket.lexeme == r'$';
    if (isShortForm && expr is SimpleIdentifier && _isTrackedField(expr.name)) {
      // Expand `$name` → `${name.value}` as a single edit. Do not descend
      // — the inner SimpleIdentifier is already handled by this rewrite.
      edits.add(
        ValueEdit(
          node.offset,
          node.end,
          '\${${expr.name}.value}',
        ),
      );
      if (_untrackedDepth == 0) {
        _recordTrackedRead(expr.offset, expr.name);
        _recordTrackedReadName(expr.name);
      }
      return;
    }
    // Widget-bound field inside short-form interpolation: `$label` must
    // expand to `${widget.label}` because `$widget.label` would parse as
    // `${widget}.label` (interpolating the State's `widget` getter, then
    // concatenating literal `.label`). Emit as a single replacement edit
    // and stop descent so the inner SimpleIdentifier doesn't also get a
    // `widget.` prefix.
    if (isShortForm &&
        expr is SimpleIdentifier &&
        _widgetBoundFields.contains(expr.name) &&
        !_isShadowed(expr.name)) {
      edits.add(
        ValueEdit(
          node.offset,
          node.end,
          '\${widget.${expr.name}}',
        ),
      );
      return;
    }
    super.visitInterpolationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (_isTrackedField(name)) {
      if (_isAccessOnSignalApi(node, _signalApiGetters)) {
        // `.hasValue` / `.previousValue` flip with signal updates, so the
        // enclosing subtree must still be wrapped — track here. Explicit
        // `.value` is the user opting out of auto-tracking, so we let the
        // bare-read path handle that case and skip recording here.
        if (_isAccessOnSignalApi(node, _trackedSignalApiGetters) &&
            _untrackedDepth == 0) {
          _recordTrackedRead(node.offset, name);
          _recordTrackedReadName(name);
        }
        return;
      }

      // Collection-typed `@SolidState` fields: ListSignal / SetSignal /
      // MapSignal expose their underlying collection API directly via
      // mixin, so chain accesses (`xs.length`, `xs.add(x)`, `xs[i]`)
      // resolve through the mixin and notify subscribers from inside the
      // reactive primitive. A bare reference is different — the local
      // variable, return value, or argument captures the ListSignal
      // object identity, which does NOT subscribe the surrounding
      // reactive context (a `Computed` body that just returns the
      // collection signal would never invalidate). So bare reads STILL
      // get the standard `.value` append; only chain prefixes skip it.
      if (_collectionFields.contains(name)) {
        if (_isChainPrefix(node)) {
          if (_untrackedDepth == 0) {
            _recordTrackedRead(node.offset, name);
            _recordTrackedReadName(name);
          }
          return;
        }
        if (!_isBareReferenceToField(node)) return;
        edits.add(ValueEdit(node.end, node.end, '.value'));
        final isGet = node.inGetterContext();
        final isSet = node.inSetterContext();
        if (isGet && !isSet && _untrackedDepth == 0) {
          _recordTrackedRead(node.offset, name);
          _recordTrackedReadName(name);
        }
        return;
      }

      if (!_isBareReferenceToField(node)) return;

      edits.add(ValueEdit(node.end, node.end, '.value'));

      final isGet = node.inGetterContext();
      final isSet = node.inSetterContext();
      // A compound write (`+=`, `++`, etc.) is getter+setter; writes never
      // subscribe, so both pure writes and compound writes are excluded
      // from tracked reads.
      if (isGet && !isSet && _untrackedDepth == 0) {
        _recordTrackedRead(node.offset, name);
        _recordTrackedReadName(name);
      }
      return;
    }

    // Bare reference to a widget-bound field inside a body that moves into
    // the State class (build, effects, computed, dispose, …). The State
    // accesses widget-config props through its `widget` getter.
    if (_widgetBoundFields.contains(name) && !_isShadowed(name)) {
      if (!_isBareReferenceToField(node)) return;
      edits.add(ValueEdit(node.offset, node.offset, 'widget.'));
    }
  }

  /// True if [id] occupies the receiver position of a chain access —
  /// the prefix of a `PrefixedIdentifier`, OR any of the four
  /// chain-target shapes covered by [_isAnyChainTarget]. Used by the
  /// collection-field branch of [visitSimpleIdentifier] to recognise
  /// `xs.<member>`, `xs.method(...)`, `xs[i]`, and `xs..add(1)..add(2)`
  /// cascades — all of which resolve through the collection-signal mixin
  /// and must NOT receive a `.value` append.
  bool _isChainPrefix(SimpleIdentifier id) {
    final parent = id.parent;
    if (parent is PrefixedIdentifier && parent.prefix == id) return true;
    return _isAnyChainTarget(id);
  }

  /// Appends [name] to [trackedReadNames] iff not already present, preserving
  /// source-first-appearance order. A query body that reads the same Signal
  /// at multiple offsets — e.g. `'$userId-$userId'` — must contribute the
  /// name exactly once to the source-Computed tuple.
  void _recordTrackedReadName(String name) {
    if (!trackedReadNames.contains(name)) trackedReadNames.add(name);
  }

  /// Records [offset] as a tracked read keyed by signal [name]. Map
  /// insertion order is source-first-appearance because Dart's `Map<K, V>`
  /// literal preserves insertion order, so downstream consumers can iterate
  /// `trackedReadNamesByOffset.keys` in the same order as a parallel list
  /// would emit. Every caller is in a branch that already verified
  /// `_untrackedDepth == 0`.
  void _recordTrackedRead(int offset, String name) {
    trackedReadNamesByOffset[offset] = name;
  }

  /// Appends [name] to [trackedQueryNames] iff not already present,
  /// preserving source-first-appearance order. A query body that calls the
  /// same upstream `<query>()` at multiple offsets must contribute the name
  /// exactly once to the synthesized source-Computed tuple.
  void _recordTrackedQueryName(String name) {
    if (!trackedQueryNames.contains(name)) trackedQueryNames.add(name);
  }

  /// Appends the `(envField, name)` pair to [trackedCrossClassReadNames] iff
  /// not already present, preserving source-first-appearance order. A query
  /// body reading the same cross-class signal at multiple offsets contributes
  /// the pair exactly once to the synthesized source-Computed tuple.
  void _recordTrackedCrossClassRead(String envField, String name) {
    for (final p in trackedCrossClassReadNames) {
      if (p.envField == envField && p.name == name) return;
    }
    trackedCrossClassReadNames.add((envField: envField, name: name));
  }

  /// True if [id] sits in receiver position of a chain access whose property
  /// name is in [propertyNames]. The two callers pivot the rule:
  ///   * [_signalApiGetters] — no-double-append guard.
  ///   * [_trackedSignalApiGetters] — `.hasValue` / `.previousValue` reads
  ///     that must record a tracking offset for SignalBuilder placement.
  bool _isAccessOnSignalApi(SimpleIdentifier id, Set<String> propertyNames) {
    final parent = id.parent;
    if (parent is PropertyAccess &&
        parent.target == id &&
        propertyNames.contains(parent.propertyName.name)) {
      return true;
    }
    if (parent is PrefixedIdentifier &&
        parent.prefix == id &&
        propertyNames.contains(parent.identifier.name)) {
      return true;
    }
    return false;
  }

  /// Confirms the identifier is a bare reference to the field (not, for
  /// instance, the right-hand identifier in `obj.counter`, a named-argument
  /// label, a type name, or a declaration site). Only bare references need
  /// rewriting.
  bool _isBareReferenceToField(SimpleIdentifier id) {
    final parent = id.parent;
    // `obj.counter` — skip when we are the property name, since we resolve
    // to a member of `obj`, not the enclosing class field.
    if (parent is PropertyAccess && parent.propertyName == id) return false;
    if (parent is PrefixedIdentifier && parent.identifier == id) return false;
    // Named-argument label `counter: foo` — the identifier is the label.
    if (parent is Label && parent.label == id) return false;
    // Declaration site: field / variable / parameter name.
    if (parent is VariableDeclaration && parent.name == id.token) return false;
    if (parent is FormalParameter) return false;
    // Constructor / method name in a declaration.
    if (parent is ConstructorDeclaration ||
        parent is MethodDeclaration ||
        parent is FunctionDeclaration) {
      return false;
    }
    return true;
  }

  /// True if [fn] is the direct value of a `NamedExpression` whose name
  /// matches the untracked-callback pattern (see [_isOnPrefixedCallbackName]).
  bool _isUntrackedCallback(FunctionExpression fn) {
    final parent = fn.parent;
    if (parent is! NamedExpression) return false;
    return _isOnPrefixedCallbackName(parent.name.label.name);
  }
}
