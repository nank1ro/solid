import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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
/// inside user-interaction callbacks, `Key`-family constructors, or
/// `untracked(...)` calls (Section 6.2 / 6.3 / 6.4) are excluded.
class ValueRewriteResult {
  /// Creates a result holding [edits] and their [trackedReadOffsets].
  const ValueRewriteResult(this.edits, this.trackedReadOffsets);

  /// Source edits to apply for `.value` / interpolation rewrites.
  final List<ValueEdit> edits;

  /// Source offsets of reads that must be tracked for SignalBuilder
  /// placement (Section 7). A subset of the read identifiers in [edits].
  final List<int> trackedReadOffsets;
}

/// Names of callback parameters enumerated by SPEC Section 6.2. A read
/// inside a function expression that is the value of a named argument
/// with one of these parameter names is untracked.
const Set<String> _untrackedCallbackParams = {
  'onPressed',
  'onTap',
  'onLongPress',
  'onDoubleTap',
  'onChanged',
  'onSubmitted',
  'onEditingComplete',
  'onFieldSubmitted',
  'onSaved',
  'onHorizontalDragStart',
  'onHorizontalDragUpdate',
  'onHorizontalDragEnd',
  'onHorizontalDragCancel',
  'onHorizontalDragDown',
  'onVerticalDragStart',
  'onVerticalDragUpdate',
  'onVerticalDragEnd',
  'onVerticalDragCancel',
  'onVerticalDragDown',
  'onPanStart',
  'onPanUpdate',
  'onPanEnd',
  'onPanCancel',
  'onPanDown',
  'onScaleStart',
  'onScaleUpdate',
  'onScaleEnd',
  'onHover',
  'onExit',
  'onEnter',
  'onFocusChange',
  'onDismissed',
  'onClosing',
  'onAccept',
  'onWillAccept',
  'onLeave',
  'onMove',
};

/// Names of `Key`-family constructors enumerated by SPEC Section 6.3. A
/// read inside an `InstanceCreationExpression` of one of these classes
/// (passed as the `key:` argument to a widget) is untracked.
const Set<String> _keyConstructors = {
  'Key',
  'ValueKey',
  'ObjectKey',
  'UniqueKey',
  'GlobalKey',
  'GlobalObjectKey',
  'PageStorageKey',
};

/// Walks [buildMethod] and returns every offset-based value edit plus the
/// tracked-read offsets that downstream placement needs.
///
/// [reactiveFields] is the name-set of `@SolidState` fields declared on the
/// enclosing class. The rewrite is name-based (see SPEC 5.4 note in the
/// orchestrator `rewriteBuildMethod`); M3-05 upgrades to type-driven
/// resolution.
ValueRewriteResult collectValueEdits(
  MethodDeclaration buildMethod,
  Set<String> reactiveFields,
  String source,
) {
  final visitor = _ValueRewriteVisitor(reactiveFields);
  buildMethod.accept(visitor);
  return ValueRewriteResult(visitor.edits, visitor.trackedReadOffsets);
}

/// AST visitor that accumulates [ValueEdit]s for reactive-field identifiers.
///
/// Scope tracking is intentionally minimal in M1-05: a local variable whose
/// name collides with a reactive field suppresses the rewrite inside its
/// enclosing block. M3-09 replaces this heuristic with type-driven
/// shadowing resolution.
class _ValueRewriteVisitor extends RecursiveAstVisitor<void> {
  _ValueRewriteVisitor(this._reactiveFields);

  final Set<String> _reactiveFields;
  final List<ValueEdit> edits = [];
  final List<int> trackedReadOffsets = [];

  /// Stack of shadowed-name sets, one frame per enclosing block / function.
  final List<Set<String>> _scopeStack = [<String>{}];

  /// Depth of untracked contexts; >0 means every read visited here is
  /// treated as untracked.
  int _untrackedDepth = 0;

  bool _isShadowed(String name) =>
      _scopeStack.any((frame) => frame.contains(name));

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
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final untracked = _isKeyUntracked(node);
    if (untracked) _untrackedDepth++;
    super.visitInstanceCreationExpression(node);
    if (untracked) _untrackedDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final isUntrackedFn =
        node.target == null && node.methodName.name == 'untracked';
    if (isUntrackedFn) _untrackedDepth++;
    super.visitMethodInvocation(node);
    if (isUntrackedFn) _untrackedDepth--;
  }

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    final expr = node.expression;
    final isShortForm = node.leftBracket.lexeme == r'$';
    if (isShortForm &&
        expr is SimpleIdentifier &&
        _reactiveFields.contains(expr.name) &&
        !_isShadowed(expr.name)) {
      // Expand `$name` → `${name.value}` as a single edit. Do not descend
      // — the inner SimpleIdentifier is already handled by this rewrite.
      edits.add(
        ValueEdit(
          node.offset,
          node.end,
          '\${${expr.name}.value}',
        ),
      );
      if (_untrackedDepth == 0) trackedReadOffsets.add(expr.offset);
      return;
    }
    super.visitInterpolationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (!_reactiveFields.contains(name)) return;
    if (_isShadowed(name)) return;
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
    }
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

  /// True if [fn] is the direct value of a `NamedExpression` whose name is
  /// an SPEC-6.2 untracked-callback parameter.
  bool _isUntrackedCallback(FunctionExpression fn) {
    final parent = fn.parent;
    if (parent is! NamedExpression) return false;
    return _untrackedCallbackParams.contains(parent.name.label.name);
  }

  /// True if [node] is a `Key`-family constructor passed as the `key:`
  /// argument of a widget (SPEC 6.3).
  bool _isKeyUntracked(InstanceCreationExpression node) {
    final ctorName = node.constructorName.type.qualifiedName;
    if (!_keyConstructors.contains(ctorName)) return false;
    final parent = node.parent;
    if (parent is! NamedExpression) return false;
    return parent.name.label.name == 'key';
  }
}

extension on NamedType {
  /// The bare class name of a type annotation, ignoring any import prefix
  /// (e.g. `foo.ValueKey` → `ValueKey`).
  String get qualifiedName => name.lexeme;
}
