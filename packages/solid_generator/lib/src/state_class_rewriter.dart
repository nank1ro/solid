import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rewrites an existing `State<X>` subclass containing `@SolidState` fields,
/// `@SolidEffect` methods, and/or `@SolidQuery` methods **in place** —
/// without splitting the class. Replaces every `@SolidState` field with a
/// `Signal<T>(…)` declaration, every `@SolidEffect` method with a
/// `late final … = Effect(…)` field, every `@SolidQuery` method with a
/// `late final … = Resource<T>(…)` field, routes `build()` through the
/// reactive-read pipeline, and merges reactive disposals into any existing
/// `dispose()` body. When Effects exist, Effect materialization reads
/// (`<effectName>;`) are also merged into any existing `initState()` body,
/// or a fresh `initState()` is synthesized if none was declared. Queries
/// are intentionally never spliced into `initState` — Resources are lazy
/// and the late-final initializer fires on first call-site read (SPEC §4.8
/// rule 10 / §14 item 4).
///
/// See SPEC §8.2 (in-place State lowering), §10 (dispose merging), §4.7
/// (Effect materialization), and §4.8 (Resource lowering). The Signal-only
/// path is the fix for issue #3 — a `StatefulWidget` whose `State<X>`
/// subclass declared `@SolidState` fields was silently passed through
/// unchanged in v1.
///
/// Member ordering and non-annotated members (other fields,
/// `didUpdateWidget`, user methods, constructors, …) are emitted verbatim
/// from [source] so that lifecycle bodies round-trip byte-identical.
///
/// The emitted string is syntactically valid Dart but is not guaranteed to be
/// pretty-printed — run through `DartFormatter` before writing.
RewriteResult rewriteStateClass(
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
  // M2-01 ships getter→Computed for `StatelessWidget` only. The in-place
  // merge logic this rewriter is built around does not yet handle the
  // `late final ... = Computed<T>(...)` slot; reject so M1-14's valid-target
  // pass isn't silently undone here.
  rejectIfGettersNotYetSupported(
    solidGetters,
    'existing State<X> subclass',
    className,
  );
  // Index annotated fields and methods by name for O(1) lookup during the
  // member walk. The builder already parsed `@SolidState`/`@SolidEffect`/
  // `@SolidQuery` once when computing [solidFields] / [solidEffects] /
  // [solidQueries]; re-parsing here would double the annotation-reader cost
  // per file.
  final modelByName = {for (final f in solidFields) f.fieldName: f};
  final envByName = {
    for (final e in solidEnvironments) e.fieldName: e,
  };
  final effectByName = {for (final e in solidEffects) e.methodName: e};
  final queryByName = {for (final q in solidQueries) q.methodName: q};
  final reactiveNames = modelByName.keys.toSet();
  // Fields-only: getters are rejected on this rewriter today
  // (`rejectIfGettersNotYetSupported`).
  final reactiveTypeTexts = <String, String>{
    for (final f in solidFields) f.fieldName: f.typeText,
  };
  // Built once before the member walk so the `build` branch and any future
  // reactive context can share the same set without rebuilding it. Mirrors
  // the `stateless_rewriter.dart` pattern: empty-list short-circuits to a
  // shared const set so query-free classes pay zero allocation.
  final queryNames = solidQueries.isEmpty
      ? const <String>{}
      : {for (final q in solidQueries) q.methodName};
  // Built incrementally during the walk so Signal field names, Effect method
  // names, and Query method names interleave in source-declaration order —
  // the contract `emitDispose` relies on for reverse-disposal correctness
  // (SPEC §10).
  final disposeNames = <String>[];
  final effectNames = <String>[];
  final pieces = <String>[];
  // `initState`/`dispose` emission is deferred until after the walk so the
  // merge sees the fully-populated `effectNames` / `disposeNames` lists.
  // The slot index reserves the member's source-order position in `pieces`
  // so it round-trips byte-identical when the user declared one.
  MethodDeclaration? initStateMethod;
  MethodDeclaration? disposeMethod;
  var initStateSlot = -1;
  var disposeSlot = -1;

  for (final member in classDecl.members) {
    if (member is FieldDeclaration) {
      final varName = member.fields.variables.first.name.lexeme;
      final model = modelByName[varName];
      if (model != null) {
        pieces.add(emitSignalField(model));
        disposeNames.add(model.fieldName);
        continue;
      }
      final env = envByName[varName];
      if (env != null) {
        // Env fields lower to `late final … = context.read<T>();` in source-
        // declaration order. They are NOT added to `disposeNames` (SPEC §10
        // — host never owns disposal of injected instances) and NOT added to
        // `effectNames` (SPEC §4.9 rule 2 — env fields are lazy and need no
        // initState materialization).
        pieces.add(emitEnvironmentField(env));
        continue;
      }
      pieces.add(source.substring(member.offset, member.end));
      continue;
    }
    if (member is MethodDeclaration) {
      final name = member.name.lexeme;
      if (name == 'build') {
        pieces.add(
          rewriteBuildMethod(
            member,
            reactiveNames,
            source,
            queryNames: queryNames,
            classRegistry: classRegistry,
          ),
        );
      } else if (name == 'initState') {
        initStateMethod = member;
        initStateSlot = pieces.length;
        pieces.add('');
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
        // `effectNames` / `initState` materialization (SPEC §4.8 rule 10 /
        // §14 item 4). The first reactive call site triggers the late-final
        // initializer.
        final query = queryByName[name]!;
        emitQueryFields(query, reactiveTypeTexts, pieces, disposeNames);
      } else {
        pieces.add(source.substring(member.offset, member.end));
      }
      continue;
    }
    pieces.add(source.substring(member.offset, member.end));
  }

  // Custom `initState` is preserved untouched when no Effects exist (SPEC
  // §14 item 4); when Effects are present, materialization reads are
  // spliced after the existing `super.initState();` call (§14 item 4
  // carve-out + §4.7). When no `initState` was declared, synthesize one
  // iff at least one Effect needs materialization — otherwise skip, so the
  // M1-07 Signal-only golden round-trips byte-identical.
  if (initStateMethod != null) {
    pieces[initStateSlot] = effectNames.isEmpty
        ? source.substring(initStateMethod.offset, initStateMethod.end)
        : _mergeInitState(initStateMethod, effectNames, source, className);
  } else if (effectNames.isNotEmpty) {
    pieces.add(emitInitState(effectNames));
  }
  if (disposeMethod != null) {
    pieces[disposeSlot] = mergeDispose(
      disposeMethod,
      disposeNames,
      source,
      className,
    );
  } else {
    pieces.add(
      emitDispose(disposeNames, emitOverride: true, emitSuperCall: true),
    );
  }

  final header = source.substring(
    classDecl.offset,
    classDecl.leftBracket.offset,
  );
  return (
    text: '$header{\n${pieces.join('\n\n')}\n}',
    solidartNames: <String>{
      // SPEC §9 import-add gate: `Signal` is only emitted when the class
      // has at least one `@SolidState` field. An env-only host (M6-05) has
      // no Signal reference in lowered output and so does NOT pull in
      // `flutter_solidart`.
      if (solidFields.isNotEmpty) 'Signal',
      if (effectNames.isNotEmpty) 'Effect',
      // Queries emit `Resource<T>(...)` fields; their `<query>().when(...)`
      // call sites in `build` are wrapped in `SignalBuilder` by
      // `rewriteBuildMethod` when at least one query is present.
      if (solidQueries.isNotEmpty) 'Resource',
      if (solidQueries.isNotEmpty) 'SignalBuilder',
      // A multi-dep query synthesizes a Record-Computed source field,
      // requiring `Computed` in the import set even when the class has no
      // `@SolidState` getter.
      if (solidQueries.any((q) => q.needsSourceComputed)) 'Computed',
    },
  );
}

/// Splices Effect-materialization reads (`<effectName>;`, in declaration
/// order) into an existing `initState()` body immediately after the
/// `super.initState();` call, so Effects subscribe to signals before any
/// user code in `initState` runs (SPEC §4.7 + §14 item 4 carve-out).
///
/// Splice point: the end of the first statement when it is recognised as
/// `super.initState();`; otherwise immediately after the opening brace. The
/// SPEC mandates `super.initState()` first, so the fallback only fires for
/// non-conforming user code — keeping the merge adjacent to where the super
/// call would have been.
///
/// Throws [CodeGenerationError] if the existing `initState()` uses an
/// expression body (`=> …`) — the merge is only well-defined for a block.
String _mergeInitState(
  MethodDeclaration method,
  List<String> effectNamesInDeclarationOrder,
  String source,
  String className,
) {
  final body = method.body;
  if (body is! BlockFunctionBody) {
    throw CodeGenerationError(
      'existing initState() must have a block body for Effect merge',
      null,
      className,
    );
  }
  final stmts = body.block.statements;
  final int insertAt;
  if (stmts.isNotEmpty && _isSuperInitStateCall(stmts.first)) {
    insertAt = stmts.first.end;
  } else {
    insertAt = body.block.leftBracket.offset + 1;
  }
  final reads = effectNamesInDeclarationOrder
      .map((name) => '    $name;')
      .join('\n');
  return '${source.substring(method.offset, insertAt)}'
      '\n$reads'
      '${source.substring(insertAt, method.end)}';
}

/// Returns `true` when [stmt] is exactly the expression statement
/// `super.initState();`. Used by [_mergeInitState] to decide whether to
/// splice Effect reads after the user's super call (the SPEC-conforming
/// case) or at the top of the body (fallback).
bool _isSuperInitStateCall(Statement stmt) {
  if (stmt is! ExpressionStatement) return false;
  final expr = stmt.expression;
  if (expr is! MethodInvocation) return false;
  return expr.target is SuperExpression && expr.methodName.name == 'initState';
}
