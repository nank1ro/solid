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
/// `package:solid_annotations` (SPEC §10). Used to detect an existing
/// declaration in the user's `implements` clause and to splice the marker
/// into lowered headers.
const String _disposableMarkerName = 'Disposable';

/// Rewrites a plain Dart class (no widget supertype) containing `@SolidState`
/// fields, `@SolidEffect` methods, and/or `@SolidQuery` methods by replacing
/// each annotated field with a `Signal<T>(…)`, each annotated method with a
/// `late final … = Effect(…)` (Effect) or `late final … = Resource<T>(…)`
/// (Query) field, and synthesizing a `dispose()` method (or merging into a
/// user-defined one — SPEC §10 / §14 item 4). When Effects exist, a fresh
/// no-arg constructor body materializes them — the plain-class analogue of
/// the State class's `initState()` materialization (SPEC §4.7). Queries are
/// intentionally never spliced into the synthesized constructor — Resources
/// are lazy and the late-final initializer fires on first call-site read
/// (SPEC §4.8 rule 10 / §8.3).
///
/// Class header: M6-02 adds `implements Disposable` to every Solid-lowered
/// plain class per SPEC §10's marker rule (lines 1206–1210 of SPEC.md):
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
/// `dispose()`, …) are emitted verbatim — with the SPEC §5.1 same-class
/// `.value` rewrite applied to user method bodies (and the M6-02 single-
/// level cross-class slice from [classRegistry], so a `compareTo(Counter
/// other) => value - other.value;` body lowers to
/// `=> value.value - other.value.value;`). User-defined constructors are
/// still rejected — constructor-merge is deferred to a later milestone.
///
/// See SPEC §8.3 (plain-class lowering header), §10 (dispose contract +
/// `Disposable` marker rule + body merge), §14 item 4 (existing `State<X>`
/// rule, extended here to plain classes).
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
  String source,
) {
  final className = classDecl.name.lexeme;
  // M2-01 ships getter→Computed for `StatelessWidget` only; reject here so
  // M1-14's valid-target pass isn't silently undone.
  rejectIfGettersNotYetSupported(solidGetters, 'plain class', className);
  // SPEC §3.6: `@SolidEnvironment` requires a `BuildContext`, which only
  // widget/state hosts provide — plain classes cannot resolve `context.read`.
  // The user-facing rejection comes from `validateSolidEnvironmentTargets`;
  // this is defense-in-depth to catch any path that bypasses validation
  // (mirrors `readSolidEffectMethod`'s defensive `decl.isStatic` skip).
  if (solidEnvironments.isNotEmpty) {
    throw CodeGenerationError(
      '@SolidEnvironment on plain class is invalid — '
      'no BuildContext available',
      null,
      className,
    );
  }
  // Source-ordered emission so Signal fields, Effect fields, and Resource
  // fields interleave by declaration order — required by SPEC §10's
  // reverse-disposal rule (an Effect or Resource must be declared after the
  // Signals it reads, so reverse order disposes dependents before their
  // dependencies).
  final fieldByName = {for (final f in solidFields) f.fieldName: f};
  final effectByName = {for (final e in solidEffects) e.methodName: e};
  final queryByName = {for (final q in solidQueries) q.methodName: q};
  // Fields-only: getters are rejected on this rewriter today
  // (`rejectIfGettersNotYetSupported`).
  final reactiveTypeTexts = <String, String>{
    for (final f in solidFields) f.fieldName: f.typeText,
  };
  final reactiveNames = fieldByName.keys.toSet();

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

  for (final member in classDecl.members) {
    if (member is ConstructorDeclaration) {
      // Constructor-merge would need to gate the synthesized Effect-
      // materialization constructor; deferred to a later milestone.
      throw CodeGenerationError(
        'plain class with constructor is not yet supported',
        null,
        className,
      );
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
      if (name == 'dispose') {
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
        // `effectNames`, so the synthesized constructor below skips them
        // (SPEC §4.8 rule 10 / §8.3).
        final query = queryByName[name]!;
        emitQueryFields(query, reactiveTypeTexts, pieces, disposeNames);
      } else {
        pieces.add(
          _rewriteUserMethod(member, reactiveNames, classRegistry, source),
        );
      }
      continue;
    }
    pieces.add(source.substring(member.offset, member.end));
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
  // No-arg constructor: only when Effects need materialization. When the
  // user declared `dispose()`, place the constructor immediately before
  // the (slot-reserved) dispose body so the rendered order is fields →
  // ctor → dispose.
  if (disposeMethod != null) {
    pieces[disposeSlot] = disposeText;
    if (effectNames.isNotEmpty) {
      pieces.insert(disposeSlot, emitConstructor(className, effectNames));
    }
  } else {
    if (effectNames.isNotEmpty) {
      pieces.add(emitConstructor(className, effectNames));
    }
    pieces.add(disposeText);
  }

  final header = _buildHeaderWithDisposable(classDecl, source);
  return (
    text: '$header{\n${pieces.join('\n\n')}\n}',
    solidartNames: <String>{
      'Signal',
      if (effectNames.isNotEmpty) 'Effect',
      if (solidQueries.isNotEmpty) 'Resource',
      // A multi-dep query synthesizes a Record-Computed source field,
      // requiring `Computed` in the import set.
      if (solidQueries.any((q) => q.needsSourceComputed)) 'Computed',
    },
  );
}

/// Returns the verbatim class header (everything from `class` up to the
/// opening `{`) with `Disposable` merged into the `implements` clause per
/// SPEC §10 (lines 1206–1210). `extends` and `with` clauses are preserved
/// verbatim.
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

/// Emits a non-annotated user method with the SPEC §5.1 `.value` rewrite
/// applied to its body — both the same-class branch (bare `SimpleIdentifier`
/// reads of [reactiveFields]) and the cross-class single-level branch from
/// [classRegistry] in one AST walk.
String _rewriteUserMethod(
  MethodDeclaration method,
  Set<String> reactiveFields,
  Map<String, Set<String>> classRegistry,
  String source,
) {
  final result = collectValueEdits(
    method,
    reactiveFields,
    source,
    classRegistry: classRegistry,
  );
  return applyEditsToRange(
    source.substring(method.offset, method.end),
    result.edits,
    method.offset,
  );
}
