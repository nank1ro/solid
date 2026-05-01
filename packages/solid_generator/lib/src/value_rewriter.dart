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
/// offsets of reads that count as "tracked" for SPEC Section 7 placement.
///
/// A tracked read is one that must cause its enclosing widget subtree to
/// subscribe (Section 6.5). Writes (Section 6.0) never appear here; reads
/// inside user-interaction callbacks (Section 6.2) or `<field>.untracked`
/// reads (Section 6.4) are excluded.
class ValueRewriteResult {
  /// Creates a result holding [edits], [trackedReadOffsets], and
  /// [trackedReadNames].
  const ValueRewriteResult(
    this.edits,
    this.trackedReadOffsets,
    this.trackedReadNames,
  );

  /// Source edits to apply for `.value` / interpolation rewrites.
  final List<ValueEdit> edits;

  /// Source offsets of reads that must be tracked for SignalBuilder
  /// placement (Section 7). A subset of the read identifiers in [edits].
  final List<int> trackedReadOffsets;

  /// Names of `@SolidState` field/getter identifiers read in tracked
  /// position, in source-first-appearance order, deduplicated. Mirrors
  /// [trackedReadOffsets] minus the offset → name lookup, restricted to
  /// reactive-field reads (NOT query-call invocations). Consumed by
  /// `readSolidQueryMethod` (M5-10) to wire the Resource's `source:`
  /// argument: zero names → no source, one name → direct pass, two or
  /// more names → synthesized Record-Computed source field.
  final List<String> trackedReadNames;
}

/// True if [name] matches the SPEC Section 6.2 untracked-callback pattern:
/// a named argument whose name starts with `on` followed by an uppercase
/// ASCII letter. Matches every Flutter built-in callback (`onPressed`,
/// `onTap`, `onChanged`, `onHorizontalDragUpdate`, …) and any user-defined
/// `on*` callback on a custom widget (`onTrigger`, `onRefresh`, …).
///
/// Per SPEC 6.2 the rule is paired with a `FunctionExpression` value guard
/// at the call site, so non-callback `on*` named args (e.g. an enum or a
/// Duration) never match.
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
/// `m3_05_type_aware_no_double_append` golden locks in the no-double-append
/// guarantee at the name-set boundary. Full SPEC §5.4 type-driven resolution
/// (`buildStep.resolver.compilationUnitFor` + `staticType` subtype queries)
/// is deferred — it is the architectural prerequisite for M3-09 (shadowing).
///
/// [queryNames] is the name-set of `@SolidQuery` methods declared on the
/// enclosing class (M5-01). Zero-argument `MethodInvocation`s whose target is
/// a bare `SimpleIdentifier` matching a query name (and not shadowed, and not
/// inside an untracked context) have their offsets recorded in
/// [ValueRewriteResult.trackedReadOffsets] so SPEC §7 SignalBuilder placement
/// can wrap their enclosing widget subtree (SPEC §4.8 rule 3). NO source
/// edit is emitted for the call expression itself — the call survives
/// byte-identical because the lowered `<name>()` resolves through
/// `Resource<T>.call() => state` to upstream extensions on `ResourceState<T>`.
///
/// [classRegistry] is the cross-class reactivity map (class name → reactive
/// field/getter names). M6-02 ships a single-level slice of SPEC §5.1's
/// chain-aware rule: `<param>.<reactiveField>` shapes where `<param>` is a
/// method parameter declared with a typed annotation that names a class in
/// [classRegistry] receive a trailing `.value`. M6-04 widens the receiver
/// shape to also include `@SolidEnvironment late T name;` host-class fields
/// via [environmentFields]. Full chains (`a.b.c.d` per SPEC §5.1) and
/// arbitrary receivers (locals, method-call results) still require the
/// resolved-AST migration mandated by SPEC §5.4 and remain deferred. Empty
/// registry = no-op for the new path; existing same-class behavior unchanged.
///
/// [environmentFields] is the host class's `@SolidEnvironment` field map
/// (`fieldName -> typeText`) — the M6-04 sibling slice of SPEC §5.1's
/// cross-class rewrite. Empty map → no-op for the env-field branch.
///
/// [node] is typically the `build()` `MethodDeclaration` (the M1-05 path) or
/// the body expression of a `@SolidState` getter (the M2-01 path). Both share
/// the same identifier-rewrite contract; only `build()` consumes
/// [ValueRewriteResult.trackedReadOffsets] for SignalBuilder placement.
///
/// [ValueRewriteResult.trackedReadNames] is asymmetric with
/// `trackedReadOffsets`: it includes only `@SolidState` field/getter reads
/// (the source-Computed inputs for M5-10), NOT query-call invocations. Query
/// calls appear in `trackedReadOffsets` for SignalBuilder placement but not
/// in `trackedReadNames` because they are not legal `Resource.source:`
/// arguments.
ValueRewriteResult collectValueEdits(
  AstNode node,
  Set<String> reactiveFields,
  String source, {
  Set<String> queryNames = const {},
  Map<String, Set<String>> classRegistry = const {},
  Map<String, String> environmentFields = const {},
}) {
  final visitor = _ValueRewriteVisitor(
    reactiveFields,
    queryNames,
    classRegistry,
    environmentFields,
  );
  node.accept(visitor);
  return ValueRewriteResult(
    visitor.edits,
    visitor.trackedReadOffsets,
    visitor.trackedReadNames,
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
/// `solid_annotations` (SPEC §6.4). Must stay in sync with the extension
/// declaration in `packages/solid_annotations/lib/src/annotations.dart`.
const String _untrackedGetterName = 'untracked';

/// Name of the runtime opt-out getter on `ReadableSignal<T>` from
/// `flutter_solidart`. Reading via this getter never subscribes the
/// surrounding reactive context.
const String _untrackedValueGetterName = 'untrackedValue';

/// AST visitor that accumulates [ValueEdit]s for reactive-field identifiers.
///
/// Scope tracking is intentionally minimal in M1-05: a local variable whose
/// name collides with a reactive field suppresses the rewrite inside its
/// enclosing block. M3-09 replaces this heuristic with type-driven
/// shadowing resolution.
class _ValueRewriteVisitor extends RecursiveAstVisitor<void> {
  _ValueRewriteVisitor(
    this._reactiveFields,
    this._queryNames,
    this._classRegistry,
    this._environmentFields,
  );

  final Set<String> _reactiveFields;

  /// Per-class set of `@SolidQuery` method names. Empty when collecting edits
  /// for a non-`build` body (M5-01 query-call detection only fires on
  /// `build`'s body, where SignalBuilder placement consumes the offsets).
  final Set<String> _queryNames;

  /// Cross-class reactivity map (class name → reactive field/getter names).
  /// Drives the single-level cross-class rewrite in [visitPrefixedIdentifier]
  /// (M6-02 slice of SPEC §5.1). Empty map → cross-class branch no-ops.
  final Map<String, Set<String>> _classRegistry;

  /// Host-class `@SolidEnvironment` field map (`fieldName -> typeText`).
  /// Drives the M6-04 sibling slice of SPEC §5.1: when the prefix of a
  /// `<id>.<reactiveField>` chain is not a method parameter but matches an
  /// env-field name on the enclosing class, the env field's declared type is
  /// looked up in [_classRegistry] for the cross-class `.value` append.
  /// Empty map → env-field branch no-ops; existing parameter-receiver
  /// behavior (m6_02_*) is unchanged.
  final Map<String, String> _environmentFields;
  final List<ValueEdit> edits = [];
  final List<int> trackedReadOffsets = [];

  /// Reactive-field/getter identifier names read in tracked position, in
  /// source-first-appearance order. Deduplicated via [_recordTrackedReadName].
  /// Excludes query-call invocations (those go to [trackedReadOffsets] only).
  final List<String> trackedReadNames = [];

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
    // SPEC §6.4: the v1 `untracked(() => ...)` function-call form is no
    // longer supported. The canonical opt-out marker is `<field>.untracked`
    // (handled in [visitPrefixedIdentifier]).
    if (node.target == null && node.methodName.name == _untrackedGetterName) {
      throw const CodeGenerationError(
        'untracked(() => ...) is no longer supported (SPEC §6.4). '
            'Use the extension getter at the call site instead, e.g. '
            '`counter.untracked`.',
        null,
        'untracked() function-call form',
      );
    }
    // SPEC §4.8 rule 3: a zero-argument call to an `@SolidQuery` method on
    // the enclosing class is a tracked read for SignalBuilder placement —
    // the runtime subscription happens inside `Resource.call()` → `state`.
    // No source edit is emitted: `fetchData()` survives byte-identical
    // because the lowered field is a `Resource<T>` whose upstream callable
    // returns `ResourceState<T>` and the trailing chain resolves to upstream
    // extensions. Shadowing follows SPEC §5.5.
    if (node.target == null &&
        node.argumentList.arguments.isEmpty &&
        _queryNames.contains(node.methodName.name) &&
        !_isShadowed(node.methodName.name) &&
        _untrackedDepth == 0) {
      trackedReadOffsets.add(node.offset);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // SPEC §6.4: rewrite `<reactiveField>.untracked` to
    // `<field>.untrackedValue` (the runtime primitive on `ReadableSignal<T>`).
    // The offset is intentionally NOT added to trackedReadOffsets and
    // `_untrackedDepth` is intentionally not consulted — an `.untracked` read
    // must never subscribe, regardless of surrounding context.
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
    // SPEC §5.1 cross-class single-level slice (M6-02 + M6-04): if the prefix
    // is a `SimpleIdentifier` resolving to either a method parameter (M6-02)
    // OR a host-class `@SolidEnvironment` field (M6-04) whose declared type
    // names a class in [_classRegistry] AND the suffix matches a reactive
    // field on that class, append `.value`. Full type-driven chain support
    // (`a.b.c.d` per SPEC §5.1) still requires the resolved-AST migration
    // mandated by SPEC §5.4. We keep this branch conservative — only single
    // `<receiver>.<field>` shapes — so the existing same-class goldens stay
    // byte-identical.
    if (_classRegistry.isNotEmpty) {
      _maybeRewriteCrossClass(node);
    }
    super.visitPrefixedIdentifier(node);
  }

  /// Single-level `<receiver>.<reactiveField>` cross-class rewrite — the
  /// shipped slice of SPEC §5.1's chain-aware rule. The receiver type
  /// resolves via [_resolveParameterTypeName] (M6-02 — method parameter)
  /// then [_environmentFields] (M6-04 — `@SolidEnvironment` host-class
  /// field); parameter wins because method parameters shadow host-class
  /// fields in Dart and are not tracked by [_isShadowed] (which covers only
  /// `visitFunctionExpression` and block-local declarations), so the lookup
  /// ORDER carries the parameter-vs-field shadowing semantics here.
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
    edits.add(ValueEdit(node.end, node.end, '.value'));
    if (_untrackedDepth == 0) {
      trackedReadOffsets.add(node.offset);
    }
  }

  /// If [prefix] resolves to a method/function parameter declared with a
  /// [NamedType] annotation, returns that type's simple name (e.g. `'Counter'`
  /// for `Counter other`). Returns `null` for parameter shapes the visitor
  /// cannot reason about in parsed AST: function-typed parameters,
  /// `var`-typed parameters, generic type-parameter receivers, and identifiers
  /// that do not resolve to a parameter at all (locals, fields, etc.). For
  /// the host-class-field case (the M6-04 `@SolidEnvironment` shape), see
  /// the sibling [_environmentFields] lookup in [_maybeRewriteCrossClass] —
  /// kept as a separate branch so the parameter-vs-field resolution order
  /// matches Dart's natural shadowing.
  ///
  /// A future PR will replace this with a `staticType` lookup on the resolved
  /// AST (SPEC §5.4 — "Name-matching, regex, or string heuristics are not
  /// acceptable"). The parameter-only resolver ships M6-02's sub-case b
  /// without dragging the resolved-AST migration into this PR; M6-04 widens
  /// the receiver shape via [_environmentFields] without requiring resolved
  /// AST either.
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
      // and SuperFormalParameter (`super.foo`) all fall through — M6-02
      // does not need them; M6-04 widens this when resolved AST lands.
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
    super.visitInterpolationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (!_isTrackedField(name)) return;
    if (_isAccessedValueProperty(node)) return;
    if (!_isBareReferenceToField(node)) return;

    edits.add(ValueEdit(node.end, node.end, '.value'));

    final isGet = node.inGetterContext();
    final isSet = node.inSetterContext();
    // A compound write (`+=`, `++`, etc.) is getter+setter; SPEC 6.0 says
    // writes never subscribe, so both pure writes and compound writes are
    // excluded from tracked reads.
    if (isGet && !isSet && _untrackedDepth == 0) {
      trackedReadOffsets.add(node.offset);
      _recordTrackedReadName(name);
    }
  }

  /// Appends [name] to [trackedReadNames] iff not already present, preserving
  /// source-first-appearance order. A query body that reads the same Signal
  /// at multiple offsets — e.g. `'$userId-$userId'` — must contribute the
  /// name exactly once to the M5-10 source-Computed tuple.
  void _recordTrackedReadName(String name) {
    if (!trackedReadNames.contains(name)) trackedReadNames.add(name);
  }

  /// Detects `counter.value` shapes where appending another `.value` would
  /// produce the `counter.value.value` regression. SPEC 5.4 handles this
  /// automatically via type resolution; in name-set mode we guard
  /// syntactically on the `.value` property name.
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
  /// matches the SPEC Section 6.2 untracked-callback pattern
  /// (see [_isOnPrefixedCallbackName]).
  bool _isUntrackedCallback(FunctionExpression fn) {
    final parent = fn.parent;
    if (parent is! NamedExpression) return false;
    return _isOnPrefixedCallbackName(parent.name.label.name);
  }
}
