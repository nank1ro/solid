import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Simple-identifier name of the `Disposable` interface from
/// `package:solid_annotations`. Used to detect an existing declaration in
/// the user's `implements` clause and to splice the marker into lowered
/// headers.
const String _disposableMarkerName = 'Disposable';

/// Rewrites a plain Dart class (no widget supertype) containing `@SolidState`
/// fields, `@SolidEffect` methods, and/or `@SolidQuery` methods by replacing
/// each annotated field with a `Signal<T>(…)`, each annotated method with a
/// `late final … = Effect(…)` (Effect) or `late final … = Resource<T>(…)`
/// (Query) field, and synthesizing a `dispose()` method (or merging into a
/// user-defined one). When Effects exist, a fresh no-arg constructor body
/// materializes them — the plain-class analogue of the State class's
/// `initState()` materialization. Queries are intentionally never spliced
/// into the synthesized constructor — Resources are lazy and the late-final
/// initializer fires on first call-site read.
///
/// Class header: `implements Disposable` is added to every Solid-lowered
/// plain class per the marker rule:
/// when no `implements` clause is present, ` implements Disposable` is
/// appended after any `extends` / `with` clauses; when one is present,
/// `, Disposable` is appended to the existing list; when `Disposable` is
/// already named (simple identifier match), the header is left unchanged.
/// The `extends` and `with` clauses are preserved verbatim.
///
/// `@override` is added to every synthesized `dispose()` (the marker
/// interface contract). When the user has declared their own `dispose()`,
/// the merge prepends synthesized reactive disposals to the user's body
/// and the user's existing `@override` (or absence thereof) is carried
/// through verbatim.
///
/// Non-annotated members (other fields, user-defined methods other than
/// `dispose()`, …) are emitted verbatim — with the same-class `.value`
/// rewrite applied to user method bodies (and the single-level cross-class
/// slice from [classRegistry], so a `compareTo(Counter other) => value -
/// other.value;` body lowers to `=> value.value - other.value.value;`).
/// User-defined constructors are still rejected — constructor-merge is
/// deferred to a later milestone.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
RewriteResult rewritePlainClass(
  ClassDeclaration classDecl,
  List<FieldModel> solidFields,
  List<GetterModel> solidGetters,
  List<EffectModel> solidEffects,
  List<QueryModel> solidQueries,
  List<EnvironmentModel> solidEnvironments,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  String source,
) {
  final className = classDecl.name.lexeme;
  // `@SolidState` getters on plain classes (Computed lowering) ARE supported
  // via the same `emitComputedField` path the stateless rewriter uses — see
  // the source-ordered walk below. The previous rejection is dropped now
  // that the walk handles getter members.
  // `@SolidEnvironment` requires a `BuildContext`, which only widget/state
  // hosts provide — plain classes cannot resolve `context.read`. The
  // user-facing rejection comes from `validateSolidEnvironmentTargets`; this
  // is defense-in-depth to catch any path that bypasses validation (mirrors
  // `readSolidEffectMethod`'s defensive `decl.isStatic` skip).
  if (solidEnvironments.isNotEmpty) {
    throw CodeGenerationError(
      '@SolidEnvironment on plain class is invalid — '
      'no BuildContext available',
      null,
      className,
    );
  }
  // Source-ordered emission so Signal fields, Computed getters, Effect
  // fields, and Resource fields interleave by declaration order — required
  // for reverse-disposal correctness (an Effect, Computed, or Resource must
  // be declared after the Signals it reads, so reverse order disposes
  // dependents before their dependencies).
  final fieldByName = {for (final f in solidFields) f.fieldName: f};
  final getterByName = {for (final g in solidGetters) g.getterName: g};
  final effectByName = {for (final e in solidEffects) e.methodName: e};
  final queryByName = {for (final q in solidQueries) q.methodName: q};
  final reactiveTypeTexts = <String, String>{
    for (final f in solidFields) f.fieldName: f.typeText,
    for (final g in solidGetters) g.getterName: g.typeText,
  };
  // Cross-query deps: each upstream's inner `T` is needed to emit
  // `ResourceState<T>` elements in the synthesized source-Computed.
  final queryInnerTypeTexts = solidQueries.isEmpty
      ? const <String, String>{}
      : {for (final q in solidQueries) q.methodName: q.innerTypeText};
  final reactiveNames = <String>{
    ...fieldByName.keys,
    ...getterByName.keys,
  };
  // Subset of `reactiveNames` whose emitter produces a collection signal
  // — drives the no-`.value`-on-chain rule in the user-method body
  // rewrite below (and in any future computed-getter / constructor-merge
  // body rewrites).
  final collectionNames = <String>{
    for (final f in solidFields)
      if (isCollectionSignalField(f)) f.fieldName,
  };

  final pieces = <String>[];
  final disposeNames = <String>[];
  final effectNames = <String>[];
  // `dispose` emission is deferred until after the walk so the merge sees
  // the fully-populated `disposeNames` list. The slot index reserves the
  // member's source-order position in `pieces` so a user-declared
  // `dispose()` round-trips at its original position relative to the
  // synthesized fields.
  MethodDeclaration? disposeMethod;
  var disposeSlot = -1;
  // User-declared constructors (zero or more) are recorded for a merged
  // emit after the walk — the merge needs `effectNames` populated to
  // splice in the Effect-materialization reads at the end of each user
  // body. Slot indices preserve source-order position. Only generative
  // constructors get the merge; factory constructors round-trip verbatim
  // (they synthesise via a delegate, not by running this ctor's body).
  final userCtors = <ConstructorDeclaration>[];
  final userCtorSlots = <int>[];

  for (final member in classDecl.members) {
    if (member is ConstructorDeclaration) {
      userCtors.add(member);
      userCtorSlots.add(pieces.length);
      pieces.add('');
      continue;
    }
    if (member is FieldDeclaration) {
      final varName = member.fields.variables.first.name.lexeme;
      final f = fieldByName[varName];
      if (f != null) {
        pieces.add(emitSignalField(f));
        disposeNames.add(f.fieldName);
      } else {
        pieces.add(source.substring(member.offset, member.end));
      }
      continue;
    }
    if (member is MethodDeclaration) {
      final name = member.name.lexeme;
      if (member.isGetter && getterByName.containsKey(name)) {
        // `@SolidState` getter on a plain class → `late final … = Computed<T>(…)`.
        // Source-order disposal puts the Computed after its dependencies so
        // the reverse-iteration `dispose()` body tears it down first.
        final getter = getterByName[name]!;
        pieces.add(emitComputedField(getter));
        disposeNames.add(getter.getterName);
      } else if (name == 'dispose') {
        disposeMethod = member;
        disposeSlot = pieces.length;
        pieces.add('');
      } else if (effectByName.containsKey(name)) {
        final effect = effectByName[name]!;
        pieces.add(emitEffectField(effect));
        disposeNames.add(effect.methodName);
        effectNames.add(effect.methodName);
      } else if (queryByName.containsKey(name)) {
        // Queries are lazy — joining `disposeNames` only, never
        // `effectNames`, so the synthesized constructor below skips them.
        final query = queryByName[name]!;
        emitQueryFields(
          query,
          reactiveTypeTexts,
          queryInnerTypeTexts,
          pieces,
          disposeNames,
        );
      } else {
        pieces.add(
          _rewriteUserMethod(
            member,
            reactiveNames,
            classRegistry,
            source,
            collectionFields: collectionNames,
            classCollectionFields: classCollectionFields,
          ),
        );
      }
      continue;
    }
    pieces.add(source.substring(member.offset, member.end));
  }

  // User-declared constructors: merge each one to splice Effect-
  // materialization reads after the user's body, apply `.value` rewrites
  // to any same-class reactive field writes (`this.signal = …` lowers to
  // `this.signal.value = …`), and strip the `const` modifier (the class
  // fields are no longer const-eligible — they hold Signal instances).
  for (var i = 0; i < userCtors.length; i++) {
    final ctor = userCtors[i];
    // Generative constructors get the merge. Factory constructors round-
    // trip verbatim: their body is a delegating return, not the host's
    // `initState`-equivalent, so spliced Effect reads would never fire.
    final isFactory = ctor.factoryKeyword != null;
    if (isFactory) {
      pieces[userCtorSlots[i]] = source.substring(ctor.offset, ctor.end);
      continue;
    }
    // Apply `.value` rewrites to the constructor body (and initializer
    // list expressions). The same `collectValueEdits` pipeline that runs
    // on user methods handles same-class field writes and cross-class
    // chain reads. The constructor's argument list and headers are
    // shielded — the visitor walks the body subtree but offsets remain
    // file-global, so `applyEditsToRange` correctly splices into the
    // merged result.
    final mergedHeaderAndBody = mergeConstructor(
      ctor,
      effectNames,
      source,
      className,
    );
    final result = collectValueEdits(
      ctor,
      reactiveNames,
      source,
      classRegistry: classRegistry,
      collectionFields: collectionNames,
      classCollectionFields: classCollectionFields,
    );
    pieces[userCtorSlots[i]] = applyEditsToRange(
      mergedHeaderAndBody,
      result.edits,
      ctor.offset,
    );
  }
  // Dispose: merge into user body if present, else synthesize. `@override`
  // is emitted in either case (the marker interface contract). On the merge
  // path the user's `@override` (if any) is carried through verbatim by
  // `mergeDispose`'s byte-for-byte slice. `super.dispose()` is never
  // emitted — a plain class's supertype is `Object` (no `dispose()` to
  // forward to).
  final disposeText = disposeMethod != null
      ? mergeDispose(disposeMethod, disposeNames, source, className)
      : emitDispose(
          disposeNames,
          emitOverride: true,
          emitSuperCall: false,
        );
  // No-arg synthesized constructor: only when (a) Effects need
  // materialization AND (b) the user did NOT declare any constructor.
  // When the user declared at least one constructor, every generative
  // user ctor already had the Effect-materialization reads spliced in
  // above (`mergeConstructor`), so an extra synthesized ctor would
  // conflict with the existing default-name ctor.
  if (disposeMethod != null) {
    pieces[disposeSlot] = disposeText;
    if (effectNames.isNotEmpty && userCtors.isEmpty) {
      pieces.insert(disposeSlot, emitConstructor(className, effectNames));
    }
  } else {
    if (effectNames.isNotEmpty && userCtors.isEmpty) {
      pieces.add(emitConstructor(className, effectNames));
    }
    pieces.add(disposeText);
  }

  final header = _buildHeaderWithDisposable(classDecl, source);
  final hasScalarSignalField = solidFields.any(
    (f) => !isCollectionSignalField(f),
  );
  final hasListSignalField = solidFields.any(
    (f) =>
        isCollectionSignalField(f) &&
        parseCollectionTypeText(f.typeText)?.ctorName == 'ListSignal',
  );
  final hasSetSignalField = solidFields.any(
    (f) =>
        isCollectionSignalField(f) &&
        parseCollectionTypeText(f.typeText)?.ctorName == 'SetSignal',
  );
  final hasMapSignalField = solidFields.any(
    (f) =>
        isCollectionSignalField(f) &&
        parseCollectionTypeText(f.typeText)?.ctorName == 'MapSignal',
  );
  return (
    text: '$header{\n${pieces.join('\n\n')}\n}',
    solidartNames: <String>{
      // Plain classes always declare at least one reactive field/getter to
      // reach this rewriter, but the field set may be entirely
      // collection-typed (`ListSignal` / `SetSignal` / `MapSignal`) so the
      // `Signal` import is only added when at least one scalar field is
      // present.
      if (hasScalarSignalField) 'Signal',
      if (hasListSignalField) 'ListSignal',
      if (hasSetSignalField) 'SetSignal',
      if (hasMapSignalField) 'MapSignal',
      if (solidGetters.isNotEmpty) 'Computed',
      if (effectNames.isNotEmpty) 'Effect',
      if (solidQueries.isNotEmpty) 'Resource',
      // A multi-dep query synthesizes a Record-Computed source field,
      // requiring `Computed` in the import set.
      if (solidQueries.any((q) => q.needsSourceComputed)) 'Computed',
    },
    emitsDisposable: true,
    constCtorNames: const <String>{},
  );
}

/// Returns the verbatim class header (everything from `class` up to the
/// opening `{`) with `Disposable` merged into the `implements` clause.
/// `extends` and `with` clauses are preserved verbatim.
String _buildHeaderWithDisposable(ClassDeclaration classDecl, String source) {
  final classStart = classDecl.offset;
  final base = source.substring(classStart, classDecl.leftBracket.offset);
  final implementsClause = classDecl.implementsClause;

  if (implementsClause == null) {
    // Splice after the last header clause that IS present.
    final beforeImplements =
        classDecl.withClause?.end ??
        classDecl.extendsClause?.end ??
        classDecl.typeParameters?.end ??
        classDecl.name.end;
    final spliceIdx = beforeImplements - classStart;
    return '${base.substring(0, spliceIdx)} implements $_disposableMarkerName'
        '${base.substring(spliceIdx)}';
  }

  final alreadyDeclared = implementsClause.interfaces.any(
    (nt) => nt.name.lexeme == _disposableMarkerName,
  );
  if (alreadyDeclared) return base;

  // Splice at the implements-clause `.end` so any trailing whitespace
  // before `{` is preserved verbatim after the splice.
  final spliceIdx = implementsClause.end - classStart;
  return '${base.substring(0, spliceIdx)}, $_disposableMarkerName'
      '${base.substring(spliceIdx)}';
}

/// Emits a non-annotated user method with the `.value` rewrite applied to
/// its body — both the same-class branch (bare `SimpleIdentifier` reads of
/// [reactiveFields]) and the cross-class single-level branch from
/// [classRegistry] in one AST walk. [collectionFields] and
/// [classCollectionFields] suppress `.value` insertion for collection-typed
/// reactive fields (`ListSignal` / `SetSignal` / `MapSignal`) on the chain-
/// access and bare-read paths.
String _rewriteUserMethod(
  MethodDeclaration method,
  Set<String> reactiveFields,
  Map<String, Set<String>> classRegistry,
  String source, {
  Set<String> collectionFields = const {},
  Map<String, Set<String>> classCollectionFields = const {},
}) {
  final result = collectValueEdits(
    method,
    reactiveFields,
    source,
    classRegistry: classRegistry,
    collectionFields: collectionFields,
    classCollectionFields: classCollectionFields,
  );
  return applyEditsToRange(
    source.substring(method.offset, method.end),
    result.edits,
    method.offset,
  );
}
