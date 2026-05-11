import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:solid_generator/src/transformation_error.dart';

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
  /// Creates a result holding [edits], [trackedReadOffsets],
  /// [trackedReadNames], [trackedQueryNames], and [selfCycleFound].
  const ValueRewriteResult(
    this.edits,
    this.trackedReadOffsets,
    this.trackedReadNames,
    this.trackedQueryNames,
    // Positional to keep the constructor signature consistent with the four
    // list-typed args above; the field is single-use sentinel data.
    // ignore: avoid_positional_boolean_parameters
    this.selfCycleFound,
  );

  /// Source edits to apply for `.value` / interpolation rewrites.
  final List<ValueEdit> edits;

  /// Source offsets of reads that must be tracked for SignalBuilder
  /// placement (Section 7). A subset of the read identifiers in [edits].
  final List<int> trackedReadOffsets;

  /// Names of `@SolidState` field/getter identifiers read in tracked
  /// position, in source-first-appearance order, deduplicated.
  final List<String> trackedReadNames;

  /// Same-class `@SolidQuery` method names invoked as zero-arg tracked calls,
  /// in source-first-appearance order, deduplicated. Disjoint from
  /// [trackedReadNames]; a query dep contributes element type
  /// `ResourceState<T>` (read via `<name>.state`) to the synthesized
  /// Record-Computed source.
  final List<String> trackedQueryNames;

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
/// `@SolidEnvironment` types is now wired via `BuildStep.resolver` (see
/// `builder.dart::_populateCrossFileTypes`) — `[classRegistry]` and
/// `[classCollectionFields]` already include cross-file entries by the
/// time this function is called. Full `staticType` subtype queries
/// (covering arbitrary parameter / local-receiver shapes) remain deferred
/// — they are the architectural prerequisite for shadowing support.
///
/// [queryNames] is the name-set of `@SolidQuery` methods declared on the
/// enclosing class. Zero-argument `MethodInvocation`s whose target is
/// a bare `SimpleIdentifier` matching a query name (and not shadowed, and not
/// inside an untracked context) have their offsets recorded in
/// [ValueRewriteResult.trackedReadOffsets] so SignalBuilder placement can
/// wrap their enclosing widget subtree. NO source edit is emitted for the
/// call expression itself — the call survives byte-identical because the
/// lowered `<name>()` resolves through `Resource<T>.call() => state` to
/// upstream extensions on `ResourceState<T>`.
///
/// [classRegistry] is the cross-class reactivity map (class name → reactive
/// field/getter names). The implementation ships a single-level slice of
/// the chain-aware rule: `<param>.<reactiveField>` shapes where `<param>`
/// is a method parameter declared with a typed annotation that names a
/// class in [classRegistry] receive a trailing `.value`. The receiver shape
/// also includes `@SolidEnvironment late T name;` host-class fields via
/// [environmentFields]. Full chains (`a.b.c.d`) and arbitrary receivers
/// (locals, method-call results) still require the resolved-AST migration
/// and remain deferred. Empty registry = no-op for the new path; existing
/// same-class behavior unchanged.
///
/// [environmentFields] is the host class's `@SolidEnvironment` field map
/// (`fieldName -> typeText`) — the sibling slice of the cross-class
/// rewrite. Empty map → no-op for the env-field branch.
///
/// [node] is typically the `build()` `MethodDeclaration` or the body
/// expression of a `@SolidState` getter. Both share the same
/// identifier-rewrite contract; only `build()` consumes
/// [ValueRewriteResult.trackedReadOffsets] for SignalBuilder placement.
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
    visitor.trackedReadOffsets,
    visitor.trackedReadNames,
    visitor.trackedQueryNames,
    visitor.selfCycleFound,
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

/// Name of the marker getter exposed by `UntrackedExtension` in
/// `solid_annotations`. Must stay in sync with the extension declaration in
/// `packages/solid_annotations/lib/src/annotations.dart`.
const String _untrackedGetterName = 'untracked';

/// Name of the runtime opt-out getter on `ReadableSignal<T>` from
/// `flutter_solidart`. Reading via this getter never subscribes the
/// surrounding reactive context.
const String _untrackedValueGetterName = 'untrackedValue';

/// Name of the runtime opt-out accessor on `Resource<T>` from
/// `flutter_solidart`. Reading via this getter returns the current
/// `ResourceState<T>` without registering a subscription on the surrounding
/// tracking context.
const String _untrackedStateGetterName = 'untrackedState';

/// AST visitor that accumulates [ValueEdit]s for reactive-field identifiers.
///
/// Scope tracking is intentionally minimal: a local variable whose name
/// collides with a reactive field suppresses the rewrite inside its
/// enclosing block. A future type-driven shadowing pass will replace this
/// heuristic.
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
  final List<int> trackedReadOffsets = [];

  /// Reactive-field/getter identifier names read in tracked position, in
  /// source-first-appearance order. Deduplicated via [_recordTrackedReadName].
  /// Excludes query-call invocations (those go to [trackedQueryNames]).
  final List<String> trackedReadNames = [];

  /// Same-class `@SolidQuery` method names invoked as tracked zero-arg
  /// calls. Source-first-appearance order, deduplicated.
  final List<String> trackedQueryNames = [];

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
    // The function-call form `untracked(() => ...)` is rejected; the
    // canonical opt-out marker is `<field>.untracked` (handled in
    // [visitPrefixedIdentifier]).
    if (node.target == null && node.methodName.name == _untrackedGetterName) {
      throw const CodeGenerationError(
        'untracked(() => ...) is not supported. '
            'Use the extension getter at the call site instead, e.g. '
            '`counter.untracked`.',
        null,
        'untracked() function-call form',
      );
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
      trackedReadOffsets.add(node.offset);
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
        parent.propertyName.name == _untrackedGetterName &&
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
    if (node.propertyName.name == _untrackedGetterName &&
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
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Rewrite `<reactiveField>.untracked` to `<field>.untrackedValue` (the
    // runtime primitive on `ReadableSignal<T>`). The offset is intentionally
    // NOT added to trackedReadOffsets and `_untrackedDepth` is intentionally
    // not consulted — an `.untracked` read must never subscribe, regardless
    // of surrounding context.
    if (node.identifier.name == _untrackedGetterName &&
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
  /// [_resolveParameterTypeName] (method parameter) then [_environmentFields]
  /// (`@SolidEnvironment` host-class field); parameter wins because method
  /// parameters shadow host-class fields in Dart and are not tracked by
  /// [_isShadowed] (which covers only `visitFunctionExpression` and
  /// block-local declarations), so the lookup ORDER carries the
  /// parameter-vs-field shadowing semantics here.
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
    if (_isAccessedValueProperty(node.identifier)) return;
    final declaredTypeName =
        _resolveParameterTypeName(node.prefix) ??
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
      trackedReadOffsets.add(node.offset);
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

  /// If [prefix] resolves to a method/function parameter declared with a
  /// [NamedType] annotation, returns that type's simple name (e.g. `'Counter'`
  /// for `Counter other`). Returns `null` for parameter shapes the visitor
  /// cannot reason about in parsed AST: function-typed parameters,
  /// `var`-typed parameters, generic type-parameter receivers, and identifiers
  /// that do not resolve to a parameter at all (locals, fields, etc.). For
  /// the host-class-field case (the `@SolidEnvironment` shape), see
  /// the sibling [_environmentFields] lookup in [_maybeRewriteCrossClass] —
  /// kept as a separate branch so the parameter-vs-field resolution order
  /// matches Dart's natural shadowing.
  ///
  /// A future revision will replace this with a `staticType` lookup on the
  /// resolved AST. The parameter-only resolver and the env-field receiver
  /// widening both work without requiring resolved AST.
  String? _resolveParameterTypeName(SimpleIdentifier prefix) {
    final method = prefix.thisOrAncestorOfType<MethodDeclaration>();
    final fn = prefix.thisOrAncestorOfType<FunctionExpression>();
    final params = method?.parameters?.parameters ?? fn?.parameters?.parameters;
    if (params == null) return null;
    for (final param in params) {
      final inner = param is DefaultFormalParameter ? param.parameter : param;
      if (inner.name?.lexeme != prefix.name) continue;
      if (inner is SimpleFormalParameter) {
        final type = inner.type;
        if (type is NamedType) return type.name.lexeme;
      }
      // FieldFormalParameter (`this.foo`), FunctionTypedFormalParameter,
      // and SuperFormalParameter (`super.foo`) all fall through —
      // unsupported until resolved AST lands.
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
        trackedReadOffsets.add(expr.offset);
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
      if (_isAccessedValueProperty(node)) return;

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
            trackedReadOffsets.add(node.offset);
            _recordTrackedReadName(name);
          }
          return;
        }
        if (!_isBareReferenceToField(node)) return;
        edits.add(ValueEdit(node.end, node.end, '.value'));
        final isGet = node.inGetterContext();
        final isSet = node.inSetterContext();
        if (isGet && !isSet && _untrackedDepth == 0) {
          trackedReadOffsets.add(node.offset);
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
        trackedReadOffsets.add(node.offset);
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

  /// Appends [name] to [trackedQueryNames] iff not already present,
  /// preserving source-first-appearance order. A query body that calls the
  /// same upstream `<query>()` at multiple offsets must contribute the name
  /// exactly once to the synthesized source-Computed tuple.
  void _recordTrackedQueryName(String name) {
    if (!trackedQueryNames.contains(name)) trackedQueryNames.add(name);
  }

  /// Detects `counter.value` shapes where appending another `.value` would
  /// produce the `counter.value.value` regression. Type resolution would
  /// handle this automatically; in name-set mode we guard syntactically on
  /// the `.value` property name.
  bool _isAccessedValueProperty(SimpleIdentifier id) {
    final parent = id.parent;
    if (parent is PropertyAccess &&
        parent.target == id &&
        parent.propertyName.name == 'value') {
      return true;
    }
    if (parent is PrefixedIdentifier &&
        parent.prefix == id &&
        parent.identifier.name == 'value') {
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
