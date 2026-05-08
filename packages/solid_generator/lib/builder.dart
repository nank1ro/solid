import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/const_call_site_rewriter.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/import_rewriter.dart';
import 'package:solid_generator/src/plain_class_rewriter.dart';
import 'package:solid_generator/src/provider_dispose_rewriter.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/reserved_annotation_validator.dart';
import 'package:solid_generator/src/state_class_rewriter.dart';
import 'package:solid_generator/src/stateless_rewriter.dart';
import 'package:solid_generator/src/target_validator.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Factory invoked by `build_runner` to create the Solid builder.
/// See SPEC Section 2.
Builder solidBuilder(BuilderOptions options) => _SolidBuilder();

/// Substring that must appear in any source file carrying a Solid annotation.
/// A file without this substring cannot possibly need transformation and is
/// skipped before `parseString` — the hot-path short-circuit for the typical
/// "no annotation" file (SPEC Section 2).
const String _solidAnnotationHint = '@Solid';

/// Substrings that flag a file as a candidate for the `Provider` /
/// `.environment<T>()` auto-dispose pass (SPEC §4.9 rule 7). The presence of
/// either substring is a cheap pre-parse hint; the visitor still rejects
/// false positives (comments, string literals, user types whose name
/// happens to contain `Provider`).
const String _providerCallHint = 'Provider';
const String _environmentCallHint = '.environment';

/// Shared formatter; `DartFormatter` construction allocates non-trivial
/// internal state, so hoisting out of `_renderOutput` avoids per-file cost.
final DartFormatter _formatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

/// Pattern matching `.environment(` and `.environment<` call sites in lowered
/// output (SPEC §9 bullet 4 keep path). Hoisted for the same reason as
/// [_formatter] — `RegExp` compiles its pattern on construction.
final RegExp _environmentExtensionRef = RegExp(r'\.environment\b');

class _SolidBuilder implements Builder {
  @override
  final Map<String, List<String>> buildExtensions = const {
    '^source/{{}}.dart': ['lib/{{}}.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    assert(
      buildStep.inputId.path.startsWith('source/'),
      'Input path must start with source/: ${buildStep.inputId.path}',
    );
    final outputId = AssetId(
      buildStep.inputId.package,
      buildStep.inputId.path.replaceFirst('source/', 'lib/'),
    );
    final source = await buildStep.readAsString(buildStep.inputId);

    // SPEC Section 2: files without any @Solid* annotation pass through
    // verbatim — UNLESS they contain a `Provider(...)` or `.environment<T>()`
    // call site, which the SPEC §4.9 rule 7 auto-dispose pass must visit. A
    // `source.contains` check is a cheap pre-parse guard — if neither marker
    // is present the file cannot need transformation.
    final hasSolidAnnotation = source.contains(_solidAnnotationHint);
    final hasProviderHint = source.contains(_providerCallHint) ||
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

    // SPEC §3.2 + §13 reserved-annotation guard. No-op at M6-01; preserved
    // as a regression fence for future SPEC revisions.
    validateReservedAnnotations(parsed.unit);
    // SPEC §3.1 invalid-target guard. Must run before
    // `_collectAnnotatedClasses`; rejected targets (final / const / static
    // fields, setters, top-level vars, methods, …) never reach the readers.
    validateSolidStateTargets(parsed.unit);
    // SPEC §3.4 invalid-target guard for `@SolidEffect`. Same contract as
    // the line above: rejected targets (getters, setters, static/abstract
    // methods, parameterized methods, non-void methods, top-level functions,
    // fields) never reach `readSolidEffectMethod`.
    validateSolidEffectTargets(parsed.unit);
    // SPEC §3.5 invalid-target guard for `@SolidQuery`. Same contract as
    // the lines above: rejected targets (non-Future/Stream returns,
    // Future-without-async bodies, parameterized/static/abstract methods,
    // getters/setters, top-level functions, fields) never reach
    // `readSolidQueryMethod`.
    validateSolidQueryTargets(parsed.unit);
    // SPEC §3.6 invalid-target guard for `@SolidEnvironment` — mirrors
    // the validators above.
    validateSolidEnvironmentTargets(parsed.unit);

    final annotatedClasses = _collectAnnotatedClasses(parsed.unit, source);
    if (annotatedClasses.every((c) => c.hasNoAnnotations)) {
      // No reactive annotations resolved. The file may still contain a
      // `Provider(...)` or `.environment<T>()` call site that the SPEC §4.9
      // rule 7 auto-dispose pass must visit; otherwise pass through verbatim.
      if (hasProviderHint) {
        final withDispose =
            addProviderDisposeAtCallSites(source, unit: parsed.unit);
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

    final classRegistry = _buildClassRegistry(annotatedClasses);
    final transformed = _renderOutput(
      parsed.unit,
      annotatedClasses,
      classRegistry,
      source,
    );
    await buildStep.writeAsString(outputId, transformed);
  }
}

/// Builds the cross-class reactivity map: class name → set of `@SolidState`
/// field/getter names declared on that class. Consumed by `value_rewriter`
/// to detect `<receiver>.<field>` reads where the receiver's declared type
/// names a class with reactive declarations (SPEC §5.1 cross-class chain
/// rewrite — single-level subset shipped in M6-02; full chains land in
/// M6-04 alongside the resolved-AST migration).
///
/// `@SolidEffect` and `@SolidQuery` names are intentionally excluded — an
/// Effect lowers to a `void`-returning `Effect` field with no observable
/// `.value`, and a Query lowers to a `Resource<T>` whose call sites resolve
/// through `Resource.call()` → `state` (no `.value` rewrite — SPEC §4.8
/// rule 2 / §5.1).
Map<String, Set<String>> _buildClassRegistry(
  List<_AnnotatedClass> annotatedClasses,
) {
  final registry = <String, Set<String>>{};
  for (final c in annotatedClasses) {
    final names = <String>{
      for (final f in c.fields) f.fieldName,
      for (final g in c.getters) g.getterName,
    };
    if (names.isNotEmpty) registry[c.decl.name.lexeme] = names;
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
/// reference an earlier annotated getter (SPEC §5.1).
List<_AnnotatedClass> _collectAnnotatedClasses(
  CompilationUnit unit,
  String source,
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
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        final model = readSolidStateField(member, source);
        if (model != null) {
          fields.add(model);
          reactiveNames.add(model.fieldName);
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
        final getter = readSolidStateGetter(member, reactiveNames, source);
        if (getter != null) {
          getters.add(getter);
          reactiveNames.add(getter.getterName);
          continue;
        }
        // Effect / query names are intentionally NOT added to
        // `reactiveNames`: `@SolidEffect` lowers to a `void`-returning
        // `Effect` with no observable `.value`, and `@SolidQuery` lowers to
        // a `Resource<T>` field whose call sites are byte-identical (no
        // `.value` rewrite) — see SPEC §4.8 rule 2 / §5.1.
        final effect = readSolidEffectMethod(member, reactiveNames, source);
        if (effect != null) {
          effects.add(effect);
          continue;
        }
        final query = readSolidQueryMethod(member, reactiveNames, source);
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

/// Renders the full `lib/` output for a file that has at least one annotated
/// class. Preserves non-annotated classes verbatim and rewrites annotated
/// ones per their class kind.
///
/// `flutter_solidart` is added to the import block iff any rewriter emitted
/// a Section 9 identifier (SPEC §9). `package:provider/provider.dart` is
/// added iff any annotated class has at least one `@SolidEnvironment` field
/// (SPEC §3.6 / §9 — env fields lower to `context.read<T>()`, which resolves
/// through `package:provider`'s `ReadContext` extension).
String _renderOutput(
  CompilationUnit unit,
  List<_AnnotatedClass> annotatedClasses,
  Map<String, Set<String>> classRegistry,
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
        _resultForClass(annotatedClasses[classIdx++], classRegistry, source)
      else
        _passthroughResult(decl, source),
  ];
  assert(
    classIdx == annotatedClasses.length,
    '_collectAnnotatedClasses must visit every ClassDeclaration in source '
    'order; otherwise the index walk above misaligns class -> rewrite pairs.',
  );

  final body = results.map((r) => r.text).join('\n\n');
  // SPEC §9 bullet 4: `Disposable` is tracked structurally on the rewriter
  // result (precise); `.environment<T>()` is detected by textual scan
  // because the call site survives verbatim from user widget code.
  // Accepted false-positive: a user method literally named `environment`
  // keeps the import live.
  final referencesSolidAnnotations =
      results.any((r) => r.emitsDisposable) ||
      _environmentExtensionRef.hasMatch(body);
  final imports = computeOutputImports(
    unit.directives.whereType<ImportDirective>().map(_importUri).toList(),
    addSolidart: results.any(
      (r) => r.solidartNames.any(solidartNames.contains),
    ),
    addProvider: annotatedClasses.any((c) => c.environments.isNotEmpty),
    referencesSolidAnnotations: referencesSolidAnnotations,
  );
  final importBlock = imports.map((u) => "import '$u';").join('\n');

  final combined = '$importBlock\n\n$body\n';
  // SPEC §4.9 rule 7. Inject
  // `dispose: (context, provider) => provider.dispose()` into every
  // `Provider(...)`, `Provider<T>(...)`, and `.environment<T>(...)` call site
  // that omits `dispose:`. Runs before `addConstAtCallSites` so the injected
  // closure (a `FunctionExpression`, never const-eligible) is part of the
  // argument list when const promotion evaluates const-eligibility.
  final withDispose = addProviderDisposeAtCallSites(combined);
  // SPEC §14 item 7 follow-up. M8-03 adds `const` to widget-ctor declarations;
  // this pass adds `const` to call sites of those declarations elsewhere in
  // the assembled output (top-level `main()`, rewritten `build` bodies,
  // passthrough classes — every scope), so `prefer_const_constructors` lint
  // stays silent end-to-end.
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
/// `@SolidQuery` lowers on every supported class kind: `StatelessWidget`
/// (M5-01), existing `State<X>` subclasses (M5-08), and plain classes
/// (M5-09). `StatefulWidget` lowering itself is the only class kind not yet
/// implemented (scheduled for a later M1 TODO).
RewriteResult _rewriteClass(
  ClassDeclaration decl,
  List<FieldModel> fields,
  List<GetterModel> getters,
  List<EffectModel> effects,
  List<QueryModel> queries,
  List<EnvironmentModel> environments,
  Map<String, Set<String>> classRegistry,
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
        source,
      );
    case ClassKind.statefulWidget:
      throw CodeGenerationError(
        'class-kind $kind is not supported yet '
        '(scheduled for a later M1 TODO)',
        null,
        className,
      );
  }
}

/// Returns the URI string of an `import '…';` directive, or the empty string
/// if the directive has no URI (should not happen for well-formed source).
String _importUri(ImportDirective d) => d.uri.stringValue ?? '';
