import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/const_call_site_rewriter.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/empty_dir_pruner.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/plain_class_rewriter.dart';
import 'package:solid_generator/src/provider_dispose_rewriter.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/reserved_annotation_validator.dart';
import 'package:solid_generator/src/signal_emitter.dart';
import 'package:solid_generator/src/state_class_rewriter.dart';
import 'package:solid_generator/src/stateless_rewriter.dart';
import 'package:solid_generator/src/target_validator.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Factory invoked by `build_runner` to create the Solid builder.
Builder solidBuilder(BuilderOptions options) => _SolidBuilder();

/// Substring that must appear in any source file carrying a Solid annotation.
/// A file without this substring cannot possibly need transformation and is
/// skipped before `parseString` — the hot-path short-circuit for the typical
/// unannotated file.
const String _solidAnnotationHint = '@Solid';

/// Substrings that flag a file as a candidate for the `Provider` /
/// `.environment<T>()` auto-dispose pass. The presence of either substring
/// is a cheap pre-parse hint; the visitor still rejects false positives
/// (comments, string literals, user types whose name happens to contain
/// `Provider`).
const String _providerCallHint = 'Provider';
const String _environmentCallHint = '.environment';

/// Shared formatter; `DartFormatter` construction allocates non-trivial
/// internal state, so hoisting out of `_renderOutput` avoids per-file cost.
final DartFormatter _formatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

/// Pattern matching `.environment(` and `.environment<` call sites in lowered
/// output (keep-path condition for `solid_annotations` imports). Hoisted for
/// the same reason as [_formatter] — `RegExp` compiles its pattern on
/// construction.
final RegExp _environmentExtensionRef = RegExp(r'\.environment\b');

class _SolidBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '^source/{{}}': ['lib/{{}}'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    assert(
      buildStep.inputId.path.startsWith('source/'),
      'Input path must start with source/: ${buildStep.inputId.path}',
    );
    // Empty-directory pruning. The `findAssets` call registers a glob
    // dependency on the source tree so this builder is re-scheduled whenever
    // any source file is added, modified, or deleted — without it,
    // `build_runner` would skip surviving inputs after an unrelated source
    // deletion and the orphan `lib/` parents would never be pruned. The prune
    // runs before the rest of the build so the current input's about-to-be-
    // written output never appears as a transient orphan.
    await buildStep.findAssets(Glob('source/**')).drain<void>();
    pruneOrphanedSubtree(Directory('lib'), Directory('source'));

    final outputId = AssetId(
      buildStep.inputId.package,
      buildStep.inputId.path.replaceFirst('source/', 'lib/'),
    );

    // Non-`.dart` inputs (assets, configs, generated `.g.dart` parts from
    // third-party generators, etc.) are copied byte-for-byte to the mirrored
    // path under `lib/`. Only `.dart` files continue through the annotation /
    // lowering pipeline below.
    if (!buildStep.inputId.path.endsWith('.dart')) {
      await buildStep.writeAsBytes(
        outputId,
        await buildStep.readAsBytes(buildStep.inputId),
      );
      return;
    }

    final source = await buildStep.readAsString(buildStep.inputId);

    // Files without any @Solid* annotation pass through verbatim — UNLESS they
    // contain a `Provider(...)` or `.environment<T>()` call site, which the
    // auto-dispose pass must visit. A `source.contains` check is a cheap
    // pre-parse guard — if neither marker is present the file cannot need
    // transformation.
    final hasSolidAnnotation = source.contains(_solidAnnotationHint);
    final hasProviderHint =
        source.contains(_providerCallHint) ||
        source.contains(_environmentCallHint);
    if (!hasSolidAnnotation && !hasProviderHint) {
      await buildStep.writeAsString(outputId, source);
      return;
    }

    final parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    for (final diagnostic in parsed.errors) {
      log.warning(
        '${buildStep.inputId}: ${diagnostic.message} '
        '(offset ${diagnostic.offset})',
      );
    }

    // Reserved-annotation guard. Currently a no-op; preserved as a regression
    // fence for future revisions.
    validateReservedAnnotations(parsed.unit);
    // Invalid-target guard for `@SolidState`. Must run before
    // `_collectAnnotatedClasses`; rejected targets (final / const / static
    // fields, setters, top-level vars, methods, …) never reach the readers.
    validateSolidStateTargets(parsed.unit);
    // Invalid-target guard for `@SolidEffect`. Same contract as the line
    // above: rejected targets (getters, setters, static/abstract methods,
    // parameterized methods, non-void methods, top-level functions, fields)
    // never reach `readSolidEffectMethod`.
    validateSolidEffectTargets(parsed.unit);
    // Invalid-target guard for `@SolidQuery`. Same contract as the lines
    // above: rejected targets (non-Future/Stream returns, Future-without-async
    // bodies, parameterized/static/abstract methods, getters/setters,
    // top-level functions, fields) never reach `readSolidQueryMethod`.
    validateSolidQueryTargets(parsed.unit);
    // Invalid-target guard for `@SolidEnvironment` — mirrors the validators
    // above.
    validateSolidEnvironmentTargets(parsed.unit);

    // Same-file class registry, built from a fast member-scan before any
    // body rewrites run. The body-rewriter relies on it to recognise
    // cross-class `.value` chains (`controller.todos`) even when the body
    // being rewritten is a `@SolidState` getter / `@SolidEffect` /
    // `@SolidQuery` on a sibling class in the same file.
    final sameFileRegistry = _prescanClassRegistry(parsed.unit);
    final sameFileCollections = _prescanClassCollectionFields(parsed.unit);
    // Cross-file resolver: walks every `package:`/relative import of the
    // current source file, redirecting same-package imports from `lib/` to
    // `source/`, and pulls in `@SolidState` member names for every class
    // referenced by a `@SolidEnvironment` field type — same contract as the
    // same-file pass, but for types declared in other source files.
    await _populateCrossFileTypes(
      parsed.unit,
      buildStep,
      sameFileRegistry,
      sameFileCollections,
    );

    final annotatedClasses = _collectAnnotatedClasses(
      parsed.unit,
      source,
      sameFileRegistry,
      sameFileCollections,
    );
    if (annotatedClasses.every((c) => c.hasNoAnnotations)) {
      // No reactive annotations resolved. The file may still contain a
      // `Provider(...)` or `.environment<T>()` call site that the auto-dispose
      // pass must visit; otherwise pass through verbatim.
      if (hasProviderHint) {
        final withDispose = addProviderDisposeAtCallSites(
          source,
          unit: parsed.unit,
        );
        if (identical(withDispose, source)) {
          await buildStep.writeAsString(outputId, source);
          return;
        }
        await buildStep.writeAsString(outputId, _formatter.format(withDispose));
        return;
      }
      await buildStep.writeAsString(outputId, source);
      return;
    }

    // Reuse the same-file + cross-file registry from the prescan above
    // (rather than rebuilding from `annotatedClasses`) — they encode the
    // same data but the prescan version is the authority because the
    // reader pipeline already consumed it.
    final transformed = _renderOutput(
      parsed.unit,
      annotatedClasses,
      sameFileRegistry,
      sameFileCollections,
      source,
    );
    await buildStep.writeAsString(outputId, transformed);
  }
}

/// Pre-scans every `ClassDeclaration` in [unit] and returns the cross-class
/// reactivity map (class name → set of `@SolidState` field / getter names).
/// Runs BEFORE `_collectAnnotatedClasses` so the produced registry can be
/// threaded into the reader pipeline, letting cross-class `.value` rewrites
/// fire even when the body being rewritten is a `@SolidState` getter /
/// `@SolidEffect` / `@SolidQuery` on a sibling class.
///
/// The scan is annotation-name-only (no body parsing) and intentionally
/// excludes `@SolidEffect` / `@SolidQuery` names for the same reason
/// `_buildClassRegistry` did: Effects have no observable `.value`, and
/// Queries lower to `Resource<T>` whose call sites resolve through
/// `Resource.call() → state`.
Map<String, Set<String>> _prescanClassRegistry(CompilationUnit unit) {
  final registry = <String, Set<String>>{};
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final names = <String>{};
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        if (member.metadata.any((a) => a.name.name == solidStateName)) {
          names.add(member.fields.variables.first.name.lexeme);
        }
      } else if (member is MethodDeclaration && member.isGetter) {
        if (member.metadata.any((a) => a.name.name == solidStateName)) {
          names.add(member.name.lexeme);
        }
      }
    }
    if (names.isNotEmpty) registry[decl.name.lexeme] = names;
  }
  return registry;
}

/// Pre-scans every `ClassDeclaration` in [unit] and returns the cross-class
/// collection-fields map (class name → set of `@SolidState` field names
/// whose emitter would produce a collection signal). Strict subset of
/// [_prescanClassRegistry] — getters are excluded because a `@SolidState`
/// getter always lowers to `Computed<T>` (no collection-mixin contract).
///
/// Mirrors the collection-detection rule in `signal_emitter.dart` so the
/// cross-file scan agrees with same-file emission: a field qualifies iff
/// the declared type matches `parseCollectionTypeText` AND it is
/// non-nullable. `late` is irrelevant — collection signals are emitted
/// even for `late` fields (with an empty default literal).
Map<String, Set<String>> _prescanClassCollectionFields(CompilationUnit unit) {
  final registry = <String, Set<String>>{};
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final names = <String>{};
    for (final member in decl.members) {
      if (member is! FieldDeclaration) continue;
      if (!member.metadata.any((a) => a.name.name == solidStateName)) continue;
      final variable = member.fields.variables.first;
      final type = member.fields.type;
      if (type == null) continue;
      if (type.question != null) continue;
      if (parseCollectionTypeText(type.toSource()) == null) continue;
      names.add(variable.name.lexeme);
    }
    if (names.isNotEmpty) registry[decl.name.lexeme] = names;
  }
  return registry;
}

/// One class declaration paired with the `@SolidState` fields and getters,
/// `@SolidEffect` methods, `@SolidQuery` methods, and `@SolidEnvironment`
/// fields it contains.
///
/// Every annotation list is empty when the class exists in the source but
/// has no reactive annotations; such classes are passed through verbatim.
class _AnnotatedClass {
  _AnnotatedClass({
    required this.decl,
    required this.fields,
    required this.getters,
    required this.effects,
    required this.queries,
    required this.environments,
  });
  final ClassDeclaration decl;
  final List<FieldModel> fields;
  final List<GetterModel> getters;
  final List<EffectModel> effects;
  final List<QueryModel> queries;
  final List<EnvironmentModel> environments;

  bool get hasNoAnnotations =>
      fields.isEmpty &&
      getters.isEmpty &&
      effects.isEmpty &&
      queries.isEmpty &&
      environments.isEmpty;
}

/// Walks [unit] once and returns every class paired with its `@SolidState`
/// fields and getters, `@SolidEffect` methods, and `@SolidQuery` methods.
/// Replaces an earlier double-walk (presence check + collection) with a
/// single traversal per file.
///
/// Fields are read first so a getter, effect, or query body's reactive-name
/// set already contains every field of the same class; getters then enter
/// the name set in source order so a later getter, effect, or query can
/// reference an earlier annotated getter.
List<_AnnotatedClass> _collectAnnotatedClasses(
  CompilationUnit unit,
  String source,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
) {
  final result = <_AnnotatedClass>[];
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final fields = <FieldModel>[];
    final getters = <GetterModel>[];
    final effects = <EffectModel>[];
    final queries = <QueryModel>[];
    final environments = <EnvironmentModel>[];
    final reactiveNames = <String>{};
    // Subset of [reactiveNames] whose emitter produces a collection signal
    // (`ListSignal<T>` / `SetSignal<T>` / `MapSignal<K, V>`). Built
    // incrementally so a `@SolidState` getter / `@SolidEffect` /
    // `@SolidQuery` body declared LATER in the class can skip the
    // `.value` insertion on chain reads of an EARLIER collection field —
    // the collection signal's mixin already tracks reads natively, so
    // `xs.where(...)` / `xs.length` / `xs[i]` resolve through the
    // ListMixin / SetMixin / MapMixin without `.value`. Getters never go
    // into this set (they lower to `Computed<T>`, no mixin contract).
    final collectionFieldsSeen = <String>{};
    // Local view of the cross-class registries that excludes the enclosing
    // class itself — the reader pipeline already provides same-class
    // `@SolidState` field/getter names through [reactiveNames], so threading
    // them through the cross-class branch a second time would double-count
    // (the chain rewrite would fire on `this.field.value` too). For env
    // injection lookups we still need the receiver-class info, hence the
    // map-of-other-classes shape.
    final selfClass = decl.name.lexeme;
    final crossClassRegistry = Map<String, Set<String>>.from(classRegistry)
      ..remove(selfClass);
    final crossClassCollections = Map<String, Set<String>>.from(
      classCollectionFields,
    )..remove(selfClass);
    // Pre-scan members once for `@SolidEnvironment` so each reader sees the
    // host class's env-field map (fieldName → typeText) up-front. The
    // env-field receiver shape (`<envField>.<reactiveField>`) needs this
    // mapping to look up the receiver's declared type in the cross-class
    // registry.
    final environmentFieldsForBody = _collectEnvironmentFields(decl);
    // A query / effect / state-getter body MAY invoke same-class `@SolidQuery`
    // methods to compose its result; the body-rewrite visitor needs the
    // per-class name set up-front to detect these cross-query reads. Pre-scan
    // members once for `@SolidQuery` annotations so each reader sees the full
    // set independent of source order (a query A can call a query B declared
    // later).
    final queryNames = _collectClassQueryNames(decl);
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        final model = readSolidStateField(member, source);
        if (model != null) {
          fields.add(model);
          reactiveNames.add(model.fieldName);
          if (isCollectionSignalField(model)) {
            collectionFieldsSeen.add(model.fieldName);
          }
          continue;
        }
        // `@SolidState` wins over `@SolidEnvironment` on a both-annotated
        // field (defense-in-depth — the target validator rejects this
        // upstream).
        final env = readSolidEnvironmentField(member, source);
        if (env != null) {
          environments.add(env);
        }
        continue;
      }
      if (member is MethodDeclaration) {
        final getter = readSolidStateGetter(
          member,
          reactiveNames,
          source,
          queryNames: queryNames,
          classRegistry: crossClassRegistry,
          classCollectionFields: crossClassCollections,
          environmentFields: environmentFieldsForBody,
          collectionFields: collectionFieldsSeen,
        );
        if (getter != null) {
          getters.add(getter);
          reactiveNames.add(getter.getterName);
          continue;
        }
        // Effect / query names are intentionally NOT added to
        // `reactiveNames`: `@SolidEffect` lowers to a `void`-returning
        // `Effect` with no observable `.value`, and `@SolidQuery` lowers to
        // a `Resource<T>` field whose call sites are byte-identical (no
        // `.value` rewrite). Cross-query dependency wiring is driven by
        // [queryNames] separately.
        final effect = readSolidEffectMethod(
          member,
          reactiveNames,
          source,
          queryNames: queryNames,
          classRegistry: crossClassRegistry,
          classCollectionFields: crossClassCollections,
          environmentFields: environmentFieldsForBody,
          collectionFields: collectionFieldsSeen,
        );
        if (effect != null) {
          effects.add(effect);
          continue;
        }
        final query = readSolidQueryMethod(
          member,
          reactiveNames,
          source,
          queryNames: queryNames,
          classRegistry: crossClassRegistry,
          classCollectionFields: crossClassCollections,
          environmentFields: environmentFieldsForBody,
          collectionFields: collectionFieldsSeen,
        );
        if (query != null) {
          queries.add(query);
        }
      }
    }
    result.add(
      _AnnotatedClass(
        decl: decl,
        fields: fields,
        getters: getters,
        effects: effects,
        queries: queries,
        environments: environments,
      ),
    );
  }
  return result;
}

/// Pre-scans [decl]'s members for `@SolidEnvironment` fields and returns
/// the `fieldName → typeText` map used by the cross-class chain rewrite
/// when the receiver is a host-class env field. Returns the shared empty
/// map when no env fields are present so the env-only path is allocation-
/// free.
Map<String, String> _collectEnvironmentFields(ClassDeclaration decl) {
  Map<String, String>? fields;
  for (final member in decl.members) {
    if (member is! FieldDeclaration) continue;
    if (!member.metadata.any((a) => a.name.name == solidEnvironmentName)) {
      continue;
    }
    final type = member.fields.type;
    if (type == null) continue;
    final fieldName = member.fields.variables.first.name.lexeme;
    (fields ??= <String, String>{})[fieldName] = type.toSource();
  }
  return fields ?? const <String, String>{};
}

/// Pre-scans [decl]'s members for `@SolidQuery`-annotated methods and
/// returns their declared names as a set. Used by `_collectAnnotatedClasses`
/// to build the per-class query-name set BEFORE the per-member reader walk,
/// so any reader (state getter / effect / query) sees the complete set
/// independent of declaration order — a `@SolidQuery` body may invoke a
/// peer query declared later in the class.
///
/// Returns the shared empty set when no `@SolidQuery` methods are present
/// to keep the zero-query path allocation-free.
Set<String> _collectClassQueryNames(ClassDeclaration decl) {
  Set<String>? names;
  for (final member in decl.members) {
    if (member is! MethodDeclaration) continue;
    if (member.isGetter || member.isSetter) continue;
    if (findAnnotationByName(solidQueryName, member.metadata) == null) continue;
    (names ??= <String>{}).add(member.name.lexeme);
  }
  return names ?? const <String>{};
}

/// Renders the full `lib/` output for a file that has at least one annotated
/// class. Preserves non-annotated classes verbatim and rewrites annotated
/// ones per their class kind.
///
/// `flutter_solidart` is added to the import block iff any rewriter emitted
/// a reactive primitive identifier. `package:provider/provider.dart` is
/// added iff any annotated class has at least one `@SolidEnvironment` field
/// (env fields lower to `context.read<T>()`, which resolves through
/// `package:provider`'s `ReadContext` extension).
String _renderOutput(
  CompilationUnit unit,
  List<_AnnotatedClass> annotatedClasses,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  String source,
) {
  // Walk `unit.declarations` in source order. Class declarations are paired
  // with `annotatedClasses` (which `_collectAnnotatedClasses` populates in
  // the same order); non-class declarations (`FunctionDeclaration`,
  // `TopLevelVariableDeclaration`, `ExtensionDeclaration`, `EnumDeclaration`,
  // `TypeAlias`, `MixinDeclaration`) are sliced verbatim from `source` —
  // without this branch, top-level `main()` and friends silently disappear.
  var classIdx = 0;
  final results = <RewriteResult>[
    for (final decl in unit.declarations)
      if (decl is ClassDeclaration)
        _resultForClass(
          annotatedClasses[classIdx++],
          classRegistry,
          classCollectionFields,
          source,
        )
      else
        _passthroughResult(decl, source),
  ];
  assert(
    classIdx == annotatedClasses.length,
    '_collectAnnotatedClasses must visit every ClassDeclaration in source '
    'order; otherwise the index walk above misaligns class -> rewrite pairs.',
  );

  final body = results.map((r) => r.text).join('\n\n');
  // `Disposable` is tracked structurally on the rewriter result (precise);
  // `.environment<T>()` is detected by textual scan because the call site
  // survives verbatim from user widget code. Accepted false-positive: a user
  // method literally named `environment` keeps the import live.
  final referencesSolidAnnotations =
      results.any((r) => r.emitsDisposable) ||
      _environmentExtensionRef.hasMatch(body);
  // Single walk of source imports: collect URIs (passed to
  // `computeOutputImports`) and the matching full directive source text in
  // one pass, so `as <prefix>` aliases and `show` / `hide` combinators survive
  // into the lowered output. Synthesized URIs (`flutter_solidart`, `provider`)
  // have no source-side directive and fall back to the bare form below.
  final sourceUris = <String>[];
  final sourceDirectives = <String, String>{};
  for (final directive in unit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri == null) continue;
    sourceUris.add(uri);
    sourceDirectives[uri] = directive.toSource();
  }
  final imports = computeOutputImports(
    sourceUris,
    addSolidart: results.any(
      (r) => r.solidartNames.any(solidartNames.contains),
    ),
    addProvider: annotatedClasses.any((c) => c.environments.isNotEmpty),
    referencesSolidAnnotations: referencesSolidAnnotations,
  );
  final importBlock = imports
      .map((u) => sourceDirectives[u] ?? "import '$u';")
      .join('\n');

  final combined = '$importBlock\n\n$body\n';
  // Inject `dispose: (context, provider) => provider.dispose()` into every
  // `Provider(...)`, `Provider<T>(...)`, and `.environment<T>(...)` call site
  // that omits `dispose:`. Runs before `addConstAtCallSites` so the injected
  // closure (a `FunctionExpression`, never const-eligible) is part of the
  // argument list when const promotion evaluates const-eligibility.
  final withDispose = addProviderDisposeAtCallSites(combined);
  // The const-ctor pass adds `const` to widget-ctor declarations; this pass
  // adds `const` to call sites of those declarations elsewhere in the assembled
  // output (top-level `main()`, rewritten `build` bodies, passthrough classes
  // — every scope), so `prefer_const_constructors` lint stays silent.
  final constCtorNames = <String>{
    for (final r in results) ...r.constCtorNames,
  };
  final withConst = addConstAtCallSites(withDispose, constCtorNames);
  return _formatter.format(withConst);
}

/// Returns a [RewriteResult] for [c]: a verbatim slice when the class has
/// no reactive annotations, otherwise the lowered output of [_rewriteClass].
RewriteResult _resultForClass(
  _AnnotatedClass c,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  String source,
) {
  if (c.hasNoAnnotations) return _passthroughResult(c.decl, source);
  return _rewriteClass(
    c.decl,
    c.fields,
    c.getters,
    c.effects,
    c.queries,
    c.environments,
    classRegistry,
    classCollectionFields,
    source,
  );
}

/// Verbatim source slice for [node], packaged as an inert [RewriteResult]
/// (no `solidart` names emitted, no `Disposable` marker). Used for
/// non-annotated classes and every non-class top-level declaration.
RewriteResult _passthroughResult(AstNode node, String source) {
  return (
    text: source.substring(node.offset, node.end),
    solidartNames: const <String>{},
    emitsDisposable: false,
    constCtorNames: const <String>{},
  );
}

/// Dispatches on [decl]'s class kind to the matching rewriter.
///
/// `@SolidQuery` lowers on every supported class kind: `StatelessWidget`,
/// existing `State<X>` subclasses, and plain classes. `StatefulWidget` as an
/// input class kind is the only one not yet implemented.
RewriteResult _rewriteClass(
  ClassDeclaration decl,
  List<FieldModel> fields,
  List<GetterModel> getters,
  List<EffectModel> effects,
  List<QueryModel> queries,
  List<EnvironmentModel> environments,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  String source,
) {
  final kind = classKindOf(decl);
  final className = decl.name.lexeme;
  switch (kind) {
    case ClassKind.statelessWidget:
      return rewriteStatelessWidget(
        decl,
        fields,
        getters,
        effects,
        queries,
        environments,
        classRegistry,
        classCollectionFields,
        source,
      );
    case ClassKind.plainClass:
      return rewritePlainClass(
        decl,
        fields,
        getters,
        effects,
        queries,
        environments,
        classRegistry,
        classCollectionFields,
        source,
      );
    case ClassKind.stateClass:
      return rewriteStateClass(
        decl,
        fields,
        getters,
        effects,
        queries,
        environments,
        classRegistry,
        classCollectionFields,
        source,
      );
    case ClassKind.statefulWidget:
      throw CodeGenerationError(
        'class-kind $kind is not supported yet',
        null,
        className,
      );
  }
}

/// Resolver pass for the cross-file slice of the chain-aware rule. For each
/// `@SolidEnvironment` field whose declared type is NOT defined in the
/// current source file, walk the imported `source/<path>.dart` file(s) via
/// `BuildStep.resolver.compilationUnitFor` and merge any `@SolidState`
/// members of the matching class declaration into [classRegistry] (and the
/// collection-subset into [classCollectionFields]).
///
/// The two registries are mutated in place. Same-file types take precedence:
/// when a type name is already present, the cross-file pass does NOT
/// overwrite it (in-file source is always the source of truth for the
/// current build).
///
/// `package:` imports of the **current package** are redirected from `lib/`
/// to `source/` because the user's `@SolidState` annotations live on the
/// pre-transformation source — the `lib/` output has already been lowered
/// (e.g. `final value = Signal<int>(0, name: 'value');`, no annotation).
/// Other-package imports (Flutter, flutter_solidart, third-party) are read
/// as-is; they have no Solid annotations and contribute nothing.
///
/// `dart:` imports are skipped — the Dart SDK contains no Solid annotations.
Future<void> _populateCrossFileTypes(
  CompilationUnit unit,
  BuildStep step,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
) async {
  // Walk every `@SolidEnvironment` field declaration in the unit. The
  // builder pre-scan does NOT pre-build env-field models — the readers do
  // that downstream — so this loop reads metadata directly off the AST.
  // Resolution is keyed on the declared `typeText`; same-file types already
  // present in [classRegistry] are skipped (the same-file pass is the
  // source of truth there).
  final wantedTypes = <String>{};
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    for (final member in decl.members) {
      if (member is! FieldDeclaration) continue;
      if (!member.metadata.any((a) => a.name.name == solidEnvironmentName)) {
        continue;
      }
      final type = member.fields.type;
      if (type == null) continue;
      final typeText = type.toSource();
      if (typeText.isEmpty) continue;
      if (classRegistry.containsKey(typeText)) continue;
      wantedTypes.add(typeText);
    }
  }
  if (wantedTypes.isEmpty) return;

  for (final directive in unit.directives.whereType<ImportDirective>()) {
    if (wantedTypes.isEmpty) break;
    final uri = directive.uri.stringValue;
    if (uri == null || uri.startsWith('dart:')) continue;
    final assetId = _resolveImportToSourceAsset(uri, step.inputId);
    if (assetId == null) continue;
    if (!assetId.path.endsWith('.dart')) continue;
    // Skip if the asset doesn't exist (e.g. an import that resolves to a
    // path the build context cannot access — pub packages without source/,
    // etc.). `canRead` is a cheap existence probe; `compilationUnitFor`
    // raises on missing assets, so this guards us before the parse.
    bool exists;
    try {
      exists = await step.canRead(assetId);
    } on Object {
      continue;
    }
    if (!exists) continue;
    final CompilationUnit imported;
    try {
      imported = await step.resolver.compilationUnitFor(assetId);
    } on Object {
      continue;
    }
    for (final decl in imported.declarations) {
      if (decl is! ClassDeclaration) continue;
      final className = decl.name.lexeme;
      if (!wantedTypes.contains(className)) continue;
      final scalarNames = <String>{};
      final collectionNames = <String>{};
      for (final member in decl.members) {
        if (member is FieldDeclaration) {
          final isSolidState = member.metadata.any(
            (a) => a.name.name == solidStateName,
          );
          if (!isSolidState) continue;
          final variable = member.fields.variables.first;
          final fieldName = variable.name.lexeme;
          scalarNames.add(fieldName);
          // Mirror the collection-detection rule in signal_emitter.dart so
          // the cross-file collection set agrees with the same-file one:
          // collection signals are emitted for any non-nullable `List<T>`
          // / `Set<T>` / `Map<K, V>` field — `late` does not exclude.
          final type = member.fields.type;
          if (type == null) continue;
          if (type.question != null) continue;
          if (parseCollectionTypeText(type.toSource()) != null) {
            collectionNames.add(fieldName);
          }
        } else if (member is MethodDeclaration && member.isGetter) {
          final isSolidState = member.metadata.any(
            (a) => a.name.name == solidStateName,
          );
          if (isSolidState) scalarNames.add(member.name.lexeme);
        }
      }
      if (scalarNames.isNotEmpty) {
        classRegistry[className] = scalarNames;
        if (collectionNames.isNotEmpty) {
          classCollectionFields[className] = collectionNames;
        }
      }
      wantedTypes.remove(className);
    }
  }
}

/// Maps an `import '<uri>';` URI to the `AssetId` of its source-side input,
/// or `null` when the import cannot be resolved.
///
/// Within the **current package**, `package:foo/path.dart` and `lib/path.dart`
/// relative imports are redirected to `source/path.dart` — the user's
/// `@SolidState` annotations live in `source/`, not the post-transformation
/// `lib/`. Other-package imports stay as-is.
AssetId? _resolveImportToSourceAsset(String uri, AssetId from) {
  final Uri parsed;
  try {
    parsed = Uri.parse(uri);
  } on Object {
    return null;
  }
  final AssetId resolved;
  try {
    resolved = AssetId.resolve(parsed, from: from);
  } on Object {
    return null;
  }
  if (resolved.package == from.package && resolved.path.startsWith('lib/')) {
    return AssetId(
      resolved.package,
      'source/${resolved.path.substring('lib/'.length)}',
    );
  }
  return resolved;
}
