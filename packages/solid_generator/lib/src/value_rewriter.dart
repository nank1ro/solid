import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
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
/// chains) and falls back to AST parameter inspection when unresolved
/// (test sandboxes without the Flutter SDK).
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
}) {
  final result = collectValueEdits(
    method,
    reactiveFields,
    source,
    classRegistry: classRegistry,
    environmentFields: environmentFields,
    collectionFields: collectionFields,
    classCollectionFields: classCollectionFields,
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
    }
    super.visitMethodInvocation(node);
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
    // Multi-level cross-class chain rewrite. `a.b.c.d` parses as
    // PropertyAccess(target=PropertyAccess(target=PrefixedIdentifier(a, b),
    // property=c), property=d); `getController().field` parses as
    // PropertyAccess(target=MethodInvocation, property=field). Both shapes
    // are caught here by resolving the receiver's `staticType` via
    // [_resolveReceiverTypeName] and looking up the property name in
    // [_classRegistry]. PrefixedIdentifier (the single-level `a.b` shape)
    // is handled by [_maybeRewriteCrossClass] above so the two paths don't
    // overlap.
    if (_classRegistry.isNotEmpty && target != null) {
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
    final declaredTypeName = _resolveReceiverTypeName(target);
    if (declaredTypeName == null) return;
    final fieldsOfType = _classRegistry[declaredTypeName];
    if (fieldsOfType == null) return;
    if (!fieldsOfType.contains(node.propertyName.name)) return;
    final collectionFieldsOfType = _classCollectionFields[declaredTypeName];
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
    // Cross-class single-level slice: if the prefix is a `SimpleIdentifier`
    // resolving to either a method parameter OR a host-class
    // `@SolidEnvironment` field whose declared type names a class in
    // [_classRegistry] AND the suffix matches a reactive field on that
    // class, append `.value`. Full type-driven chain support (`a.b.c.d`)
    // still requires the resolved-AST migration. We keep this branch
    // conservative — only single `<receiver>.<field>` shapes — so the
    // existing same-class goldens stay byte-identical.
    if (_classRegistry.isNotEmpty) {
      _maybeRewriteCrossClass(node);
    }
    super.visitPrefixedIdentifier(node);
  }

  /// Single-level `<receiver>.<reactiveField>` cross-class rewrite — the
  /// shipped slice of the chain-aware rule. The receiver type resolves via
  /// [_resolveReceiverTypeName] (parameter / local / property-of-resolved-type)
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
    final declaredTypeName =
        _resolveReceiverTypeName(node.prefix) ??
        _environmentFields[node.prefix.name];
    if (declaredTypeName == null) return;
    final fieldsOfType = _classRegistry[declaredTypeName];
    if (fieldsOfType == null) return;
    if (!fieldsOfType.contains(node.identifier.name)) return;
    final collectionFieldsOfType = _classCollectionFields[declaredTypeName];
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

  /// Returns the simple type name of [receiver], using two-tier resolution:
  ///
  ///  1. **Element-based.** When [Expression.staticType] is a resolved
  ///     [InterfaceType], return its element name. Catches locals
  ///     (`var c = controller; c.field`), method-call receivers
  ///     (`getController().field`), and parameters identically — `staticType`
  ///     is populated for every expression in resolved AST.
  ///  2. **AST fallback (parameters only).** When the resolver hasn't run
  ///     (parsed-AST fallback or test sandbox without the necessary SDK),
  ///     resolve [receiver] as a method/function parameter declared with a
  ///     [NamedType] annotation. Other receiver shapes (locals,
  ///     method-call results) cannot be resolved on parsed AST and return
  ///     `null` — the cross-class rewrite then no-ops, leaving the source
  ///     unchanged. Function-typed parameters, `var`-typed parameters,
  ///     `FieldFormalParameter`, and `SuperFormalParameter` also return
  ///     `null` in this tier.
  String? _resolveReceiverTypeName(Expression receiver) {
    final type = receiver.staticType;
    if (type is InterfaceType) return type.element.name;
    if (receiver is SimpleIdentifier) {
      return _resolveParameterTypeNameFromAst(receiver);
    }
    return null;
  }

  /// AST-only parameter resolver — the unresolved fallback for
  /// [_resolveReceiverTypeName]. Walks the prefix's enclosing
  /// [MethodDeclaration] / [FunctionExpression] for a matching
  /// [SimpleFormalParameter] and returns the declared [NamedType]'s lexeme.
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
