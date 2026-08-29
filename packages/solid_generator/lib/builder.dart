import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/const_call_site_rewriter.dart';
import 'package:solid_generator/src/cross_file_consumer_rewriter.dart';
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
import 'package:solid_generator/src/source_import_validator.dart';
import 'package:solid_generator/src/state_class_rewriter.dart';
import 'package:solid_generator/src/stateless_rewriter.dart';
import 'package:solid_generator/src/target_validator.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Factory invoked by `build_runner` to create the Solid builder.
Builder solidBuilder(BuilderOptions options) => _SolidBuilder();

/// Substring that must appear in any source file carrying a Solid annotation.
/// A file without this substring cannot need transformation via an
/// annotation of its own. It does NOT skip `parseString`, though: the file
/// may still need the `Provider`/`.environment` auto-dispose pass, or (since
/// #106) the cross-file pure-consumer probe below, either of which needs a
/// parsed unit to decide. The true zero-parse short-circuit this hint used
/// to gate no longer exists; see `build()`'s fast-path comment for what is
/// (and isn't) still cheap for the typical unannotated file.
///
/// `solid_annotations` (the package name) is the chosen hint because every
/// file that uses any `@Solid*` annotation must import this package — both
/// the canonical (`@SolidState int x = 0;`) and aliased
/// (`import '…' as sa; @sa.SolidState() int x = 0;`) shapes carry the
/// substring. The earlier `@Solid` hint missed the aliased form.
const String _solidAnnotationHint = 'solid_annotations';

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

/// Pattern matching a top-level `untracked(` or `untracked<T>(` call in lowered
/// output (the `hide untracked` keep-path condition). The word boundary and
/// `[(<]` avoid the `.untrackedValue` / `.untrackedState` getters and identifiers
/// like `myUntracked(`. Hoisted like [_environmentExtensionRef].
final RegExp _untrackedCallRef = RegExp(r'\buntracked\s*[(<]');

/// A `show` or `as` clause on an import. When present, [_hideCombinator] leaves
/// the directive alone: `show` doesn't expose the hidden name, and `as`
/// prefixes the import so there's no bare-name clash.
final RegExp _showOrAsCombinatorRef = RegExp(r'\b(?:show|as)\b');

/// An existing `hide` clause on an import. [_hideCombinator] merges the new
/// name into it (comma-separated) rather than appending a second `hide`, which
/// would warn `multiple_combinators` (fatal under `--fatal-infos`).
final RegExp _hideCombinatorRef = RegExp(r'\bhide\b');

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

    // Rejects `package:<self>/...` in any source file — runs before the
    // fast-path bypass so unannotated files are validated too.
    validateSourceImportsFromText(
      source,
      buildStep.inputId.package,
      buildStep.inputId.path,
    );

    // Files without any @Solid* annotation pass through verbatim — UNLESS
    // they contain a `Provider(...)` or `.environment<T>()` call site (the
    // auto-dispose pass must visit those), OR they are a PURE CONSUMER — a
    // file that holds a cross-file `@SolidState`-bearing class through plain
    // constructor injection / an instance field, with no `@Solid*`
    // annotation and no provider call site of its own (issue #106). A
    // `source.contains` check is a cheap pre-parse guard for the first two
    // conditions; the third needs the cheap SYNTACTIC (unresolved) parse and
    // the #105 cross-file registry seeding below to decide.
    final hasSolidAnnotation = source.contains(_solidAnnotationHint);
    final hasProviderHint =
        source.contains(_providerCallHint) ||
        source.contains(_environmentCallHint);

    final parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );

    // Populated only when the fast-path probe below actually runs AND finds
    // something — i.e. only on the `!hasSolidAnnotation && !hasProviderHint`
    // path, and only past the early return. When non-null, these are the
    // FULLY POPULATED results of a cross-file import walk this function
    // already paid for; the pipeline below (`_populateCrossFileTypes` at its
    // second call site) reuses them instead of walking the same imports
    // again — see the merge just before that call.
    Map<String, Set<String>>? probedCrossFileRegistry;
    Map<String, Set<String>>? probedCrossFileCollections;
    Map<String, Map<String, String>>? probedCrossFileFieldTypes;
    Map<String, Set<String>>? probedCrossFileOriginUris;
    // Origin-qualified counterparts (issue #110) — see
    // `_populateCrossFileTypes`'s doc comment. Populated in lockstep with
    // the four maps above; empty (never null) is a valid, common result —
    // most files resolve every wanted name unambiguously — so these are
    // merged unconditionally below rather than null-checked like the ones
    // above.
    Map<String, Map<String, Set<String>>>? probedClassRegistryOrigins;
    Map<String, Map<String, Set<String>>>? probedClassCollectionFieldsOrigins;
    Set<String>? probedClassRegistryShadowedNames;
    // Cross-class `@SolidQuery` name map (issue: cross-instance query
    // consumption) — the query counterpart of `probedCrossFileRegistry`.
    // Populated in lockstep with the maps above; a pure-query ViewModel
    // (zero `@SolidState` members) contributes ONLY here, never to
    // `probedCrossFileRegistry`, so the short-circuit below must consult
    // this map independently.
    Map<String, Set<String>>? probedCrossFileQueryNames;
    // Origin-qualified counterparts of `probedCrossFileQueryNames` (issue
    // #110 parity) — populated in lockstep, same discipline as
    // `probedClassRegistryOrigins` / `probedClassRegistryShadowedNames`.
    Map<String, Map<String, Set<String>>>? probedCrossFileQueryNamesOrigins;
    Set<String>? probedCrossFileQueryNamesShadowedNames;

    if (!hasSolidAnnotation && !hasProviderHint) {
      // Cheap syntactic pre-check (#106): seed candidate cross-file wanted
      // types from this file's instance fields / constructor params — the
      // same rule `_populateCrossFileTypes` applies below for annotated
      // files — against the UNRESOLVED parsed unit. No
      // `buildStep.resolver.libraryFor` semantic resolution runs here; that
      // is the expensive step this fast path exists to avoid.
      //
      // Honest cost accounting (this fast path's guarantee is NARROWER than
      // it used to be — see [_solidAnnotationHint]'s doc comment): `parsed`
      // above is now computed for EVERY hint-free file, annotated or not —
      // this branch could not exist without a parsed unit to probe. What
      // remains zero-cost is `_populateCrossFileTypes` itself: it exits
      // before touching any import once its wanted-type set is empty, so a
      // file with no custom-typed fields/params at all (only core-SDK /
      // self-declared types, per `_coreSdkTypeNames`) pays only the parse
      // plus this one field/param scan — no import walk, no resolver call.
      // A file whose field/param DOES name an externally-declared type pays
      // a BOUNDED import walk below — bounded by this file's own import
      // count, not by anything global — and that walk does NOT stop early
      // just because one import's same-named class turns out non-reactive:
      // `wantedTypes` only drops a name once a `@SolidState`-bearing match
      // is found (see the `cross_file_constructor_injected_no_state`
      // shape), so a non-reactive same-named class in an early import does
      // not short-circuit the scan of later imports for that name.
      final probeRegistry = <String, Set<String>>{};
      final probeCollections = <String, Set<String>>{};
      final probeFieldTypes = <String, Map<String, String>>{};
      final probeOriginUris = <String, Set<String>>{};
      final probeRegistryOrigins = <String, Map<String, Set<String>>>{};
      final probeCollectionFieldsOrigins = <String, Map<String, Set<String>>>{};
      final probeShadowedNames = <String>{};
      final probeQueryNames = <String, Set<String>>{};
      final probeQueryNamesOrigins = <String, Map<String, Set<String>>>{};
      final probeQueryNamesShadowedNames = <String>{};
      await _populateCrossFileTypes(
        parsed.unit,
        buildStep,
        probeRegistry,
        probeCollections,
        probeFieldTypes,
        probeOriginUris,
        const {},
        probeRegistryOrigins,
        probeCollectionFieldsOrigins,
        probeShadowedNames,
        probeQueryNames,
        probeQueryNamesOrigins,
        probeQueryNamesShadowedNames,
      );
      // A name issue #110's finalize pass flagged as ambiguous (shadowed by
      // a local declaration, or collided across two-plus cross-file
      // origins) is stripped from `probeRegistry` but still lives in
      // `probeShadowedNames` / `probeRegistryOrigins` — exactly the
      // `cross_file_super_param_one_hop_local_shadow` shape, where the
      // file's ONLY cross-file find is a shadowed name. Bailing out here on
      // `probeRegistry.isEmpty` alone (its pre-#110 condition) would treat
      // that file as having nothing to lower at all, silently reintroducing
      // the bug this issue fixes. `probeQueryNames` gets the same treatment,
      // plus its own shadowed-names set: a pure-query ViewModel consumer (no
      // `@SolidState` anywhere) — possibly reached only via an ambiguous,
      // origin-qualified query name — would otherwise be wrongly bailed out
      // here too.
      if (probeRegistry.isEmpty &&
          probeShadowedNames.isEmpty &&
          probeQueryNames.isEmpty &&
          probeQueryNamesShadowedNames.isEmpty) {
        await buildStep.writeAsString(outputId, source);
        return;
      }
      probedCrossFileRegistry = probeRegistry;
      probedCrossFileCollections = probeCollections;
      probedCrossFileFieldTypes = probeFieldTypes;
      probedCrossFileOriginUris = probeOriginUris;
      probedClassRegistryOrigins = probeRegistryOrigins;
      probedClassCollectionFieldsOrigins = probeCollectionFieldsOrigins;
      probedClassRegistryShadowedNames = probeShadowedNames;
      probedCrossFileQueryNames = probeQueryNames;
      probedCrossFileQueryNamesOrigins = probeQueryNamesOrigins;
      probedCrossFileQueryNamesShadowedNames = probeQueryNamesShadowedNames;
    }

    for (final diagnostic in parsed.errors) {
      log.warning(
        '${buildStep.inputId}: ${diagnostic.message} '
        '(offset ${diagnostic.offset})',
      );
    }
    // Acquire a TYPE-RESOLVED CompilationUnit when possible. Path:
    //   1. `libraryFor(inputId)` returns a fully-resolved `LibraryElement`
    //      (the analyzer resolves types fully at this step).
    //   2. `astNodeFor(anyElement, resolve: true)` returns that element's
    //      resolved declaration node — `Expression.staticType` is populated
    //      on every node beneath it.
    //   3. Navigate up to the enclosing `CompilationUnit` once.
    //
    // `compilationUnitFor` alone returns a parsed-but-unresolved unit (every
    // `staticType` is `null`), which doesn't satisfy the type-aware
    // predicates downstream (B-2 strict wrap, future shadowing, full chains).
    //
    // Fallback: when the library has no anchor element (no classes, no
    // top-level functions, etc.), there is nothing to call `astNodeFor` on,
    // so we use the parsed AST. Such files almost never carry `@Solid*`
    // annotations — annotations live on classes — so type-aware predicates
    // are a no-op there.
    final unit = await _resolveUnit(buildStep, parsed.unit);

    // AST-precise re-check of the same-package-import rule. Redundant with
    // the pre-parse text scan above but produces precise URI text in the
    // error message; one extra `whereType` walk per parsed file.
    validateSourceImportsFromAst(
      unit,
      buildStep.inputId.package,
      buildStep.inputId.path,
      source,
    );

    // Reserved-annotation guard. Currently a no-op; preserved as a regression
    // fence for future revisions.
    validateReservedAnnotations(unit);
    // Invalid-target guard for `@SolidState`. Must run before
    // `_collectAnnotatedClasses`; rejected targets (final / const / static
    // fields, setters, top-level vars, methods, …) never reach the readers.
    validateSolidStateTargets(unit);
    // Invalid-target guard for `@SolidEffect`. Same contract as the line
    // above: rejected targets (getters, setters, static/abstract methods,
    // parameterized methods, non-void methods, top-level functions, fields)
    // never reach `readSolidEffectMethod`.
    validateSolidEffectTargets(unit);
    // Invalid-target guard for `@SolidQuery`. Same contract as the lines
    // above: rejected targets (non-Future/Stream returns, Future-without-async
    // bodies, parameterized/static/abstract methods, getters/setters,
    // top-level functions, fields) never reach `readSolidQueryMethod`.
    validateSolidQueryTargets(unit);
    // Invalid-target guard for `@SolidEnvironment` — mirrors the validators
    // above.
    validateSolidEnvironmentTargets(unit);

    // Same-file class registry, built from a fast member-scan before any
    // body rewrites run. The body-rewriter relies on it to recognise
    // cross-class `.value` chains (`controller.todos`) even when the body
    // being rewritten is a `@SolidState` getter / `@SolidEffect` /
    // `@SolidQuery` on a sibling class in the same file.
    final sameFileRegistry = _prescanClassRegistry(unit);
    final sameFileCollections = _prescanClassCollectionFields(unit);
    final sameFileFieldTypes = _prescanClassFieldTypes(unit);
    // Cross-class `@SolidQuery` name map (class name → `@SolidQuery` method
    // names) — the query counterpart of `sameFileRegistry`, kept as a
    // SEPARATE registry (see `_prescanClassQueryNames`'s doc comment).
    final sameFileQueryNames = _prescanClassQueryNames(unit);
    // Origin-qualified counterpart of `sameFileQueryNames` (issue #110
    // parity) plus the shadowed-name set — mirrors `sameFileRegistryOrigins`
    // / `sameFileShadowedNames` below, but for queries.
    final sameFileQueryNamesOrigins = <String, Map<String, Set<String>>>{};
    final sameFileQueryNamesShadowedNames = <String>{};
    // Captures, per cross-class `@SolidState` field type text, the
    // `package:<self>/<lib-relative>` URIs that bring that type into scope
    // on the env-field's class file. Used by [_renderOutput] to inject the
    // import into the consumer's lib output so the synthesized
    // `Computed<(…, T, …)>` Record-Computed resolves at lib-time.
    final crossClassFieldTypeOriginUris = <String, Set<String>>{};
    // Origin-qualified counterparts of `sameFileRegistry` /
    // `sameFileCollections` (issue #110) — `name -> originUri -> fields` —
    // plus the set of names those two maps deliberately hold NO flat entry
    // for. See `_populateCrossFileTypes`'s doc comment; threaded down to
    // every reader / rewriter so `value_rewriter.dart`'s tier-1 URI match
    // can resolve a flagged name wherever a reactive body reads it.
    final sameFileRegistryOrigins = <String, Map<String, Set<String>>>{};
    final sameFileCollectionFieldsOrigins =
        <String, Map<String, Set<String>>>{};
    final sameFileShadowedNames = <String>{};
    // Cross-file resolver: walks every `package:`/relative import of the
    // current source file, redirecting same-package imports from `lib/` to
    // `source/`, and pulls in `@SolidState` member names for every class
    // referenced by a `@SolidEnvironment` field type OR created at a
    // `Provider(...)` / `.environment<T>()` call site (the latter set is
    // gathered here — see [collectProviderCreatedTypeNames] — so a
    // cross-file `@SolidState` controller that's only ever PROVIDED, never
    // consumed via `@SolidEnvironment`, still gets a `classRegistry` entry;
    // the auto-dispose pass in `_renderOutput` / the `hasProviderHint`
    // branch below relies on that entry to recognize the type as
    // Solid-lowered) — same contract as the same-file pass, but for types
    // declared in other source files.
    //
    // Skipped when the fast-path probe above already ran this exact walk
    // (only possible when `!hasSolidAnnotation && !hasProviderHint`, in
    // which case `extraWantedTypes` below is `const {}` either way, and
    // `sameFileRegistry`/etc are still empty from the same-file prescan
    // above — `hasSolidAnnotation` being false rules out any same-file
    // `@SolidState` class). `_populateCrossFileTypes` never reads
    // `Expression.staticType` — it is a purely syntactic AST + import scan —
    // so re-running it against the resolved [unit] here would produce
    // byte-identical results to the probe's run against the unresolved
    // `parsed.unit`; merging the probe's output is exactly equivalent to
    // (and cheaper than) calling it again.
    if (probedCrossFileRegistry != null) {
      sameFileRegistry.addAll(probedCrossFileRegistry);
      sameFileCollections.addAll(probedCrossFileCollections!);
      sameFileFieldTypes.addAll(probedCrossFileFieldTypes!);
      crossClassFieldTypeOriginUris.addAll(probedCrossFileOriginUris!);
      sameFileRegistryOrigins.addAll(probedClassRegistryOrigins!);
      sameFileCollectionFieldsOrigins.addAll(
        probedClassCollectionFieldsOrigins!,
      );
      sameFileShadowedNames.addAll(probedClassRegistryShadowedNames!);
      sameFileQueryNames.addAll(probedCrossFileQueryNames!);
      sameFileQueryNamesOrigins.addAll(probedCrossFileQueryNamesOrigins!);
      sameFileQueryNamesShadowedNames.addAll(
        probedCrossFileQueryNamesShadowedNames!,
      );
    } else {
      await _populateCrossFileTypes(
        unit,
        buildStep,
        sameFileRegistry,
        sameFileCollections,
        sameFileFieldTypes,
        crossClassFieldTypeOriginUris,
        hasProviderHint ? collectProviderCreatedTypeNames(unit) : const {},
        sameFileRegistryOrigins,
        sameFileCollectionFieldsOrigins,
        sameFileShadowedNames,
        sameFileQueryNames,
        sameFileQueryNamesOrigins,
        sameFileQueryNamesShadowedNames,
      );
    }

    final annotatedClasses = _collectAnnotatedClasses(
      unit,
      source,
      sameFileRegistry,
      sameFileCollections,
      sameFileRegistryOrigins,
      sameFileCollectionFieldsOrigins,
      sameFileShadowedNames,
    );
    if (annotatedClasses.every((c) => c.hasNoAnnotations)) {
      // No reactive annotations resolved. The file may still need:
      //  (a) `SignalBuilder`-wrap placement + `.value` lowering on a PURE
      //      CONSUMER `StatelessWidget`/`State<X>` (issue #106 residual gap
      //      survey, GAP 1),
      //  (b) `.value` lowering on a PURE CONSUMER plain class — one that
      //      reaches a cross-file `@SolidState`-bearing class only through
      //      constructor injection / an instance field, with no `@Solid*`
      //      annotation of its own (issue #106; `sameFileRegistry` can be
      //      non-empty here purely from the cross-file seeding above, even
      //      though this file owns zero reactive members), and/or
      //  (c) dispose-call-site injection at a `Provider(...)` /
      //      `.environment<T>()` call site (pre-existing).
      // None of the three restructures a class's `implements` clause or
      // synthesizes `dispose()` — those only belong to a class that OWNS at
      // least one reactive member (handled by `_renderOutput` below, for
      // files where SOME class does).
      //
      // (a) and (b) are collected and applied TOGETHER by
      // [lowerPureConsumers] against the pristine [source] and the
      // still-resolved [unit] — see that function's doc comment for why: an
      // earlier version ran them as two sequential text-mutating passes,
      // which forced the second pass onto an unresolved re-parse whenever
      // the first pass edited anything, silently degrading any tier-1-ONLY
      // receiver resolution (a static-holder read, a for-in loop variable,
      // `.first`) belonging to a DIFFERENT class in the same file. Merging
      // both edit sets up front removes the ordering dependency entirely.
      //
      // (c) runs after, on the ALREADY-MERGED text:
      // `addProviderDisposeAtCallSites` is explicitly designed to tolerate
      // an unresolved re-parse — its
      // `_createdTypeHasDispose` four-tier rule falls back to same-file AST
      // tiers (2/3) or the inject-by-default tier 4 whenever `.staticType`
      // isn't populated — exactly what happens on the main annotated path in
      // `_renderOutput`, which invokes this same function on `combined`, a
      // freshly re-assembled text string with no `unit` argument at all.
      // Running dispose-injection BEFORE the pure-consumer lowering (an
      // earlier order) would cost those passes their only source of
      // loop-variable / other non-parameter-non-field receiver resolution
      // whenever the dispose pass actually edited the text — reproduced by
      // the `cross_file_pure_consumer_with_provider` golden fixture.
      final lowered = lowerPureConsumers(
        source,
        unit,
        classRegistry: sameFileRegistry,
        classCollectionFields: sameFileCollections,
        classRegistryOrigins: sameFileRegistryOrigins,
        classCollectionFieldsOrigins: sameFileCollectionFieldsOrigins,
        classRegistryShadowedNames: sameFileShadowedNames,
        classQueryNames: sameFileQueryNames,
        classQueryNamesOrigins: sameFileQueryNamesOrigins,
        classQueryNamesShadowedNames: sameFileQueryNamesShadowedNames,
      );
      var current = lowered.text;
      if (hasProviderHint) {
        current = addProviderDisposeAtCallSites(
          current,
          unit: identical(current, source) ? unit : null,
          classRegistry: sameFileRegistry,
        );
      }
      // A pure-consumer widget's `SignalBuilder` wrap (GAP 1 above) needs
      // `flutter_solidart` imported — this no-annotation branch otherwise
      // never touches imports at all (unlike `_renderOutput`'s
      // `computeOutputImports` call), since `.value`-only lowering
      // introduces no new identifier that isn't already resolvable through
      // the existing imports. `lowered.emittedSignalBuilder` is
      // [lowerPureConsumers]'s own report of whether it placed a wrap — not
      // a substring scan of `current`, which would both misfire on a
      // preserved comment containing the text `SignalBuilder(` AND treat ANY
      // existing `flutter_solidart` import as sufficient even when that
      // import's `show`/`hide` combinators don't actually expose the name.
      if (lowered.emittedSignalBuilder) {
        current = _ensureSignalBuilderResolves(current, unit);
      }
      if (identical(current, source)) {
        await buildStep.writeAsString(outputId, source);
        return;
      }
      await buildStep.writeAsString(outputId, _formatter.format(current));
      return;
    }

    // Reuse the same-file + cross-file registry from the prescan above
    // (rather than rebuilding from `annotatedClasses`) — they encode the
    // same data but the prescan version is the authority because the
    // reader pipeline already consumed it.
    final transformed = _renderOutput(
      unit,
      annotatedClasses,
      sameFileRegistry,
      sameFileCollections,
      sameFileFieldTypes,
      crossClassFieldTypeOriginUris,
      buildStep.inputId,
      source,
      sameFileRegistryOrigins,
      sameFileCollectionFieldsOrigins,
      sameFileShadowedNames,
      sameFileQueryNames,
      sameFileQueryNamesOrigins,
      sameFileQueryNamesShadowedNames,
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
///
/// Caveat: every consumer of this registry (here, `_populateCrossFileTypes`,
/// and the auto-dispose type-aware check in `provider_dispose_rewriter.dart`)
/// keys it by SIMPLE class name, not library-qualified identity. Two
/// distinct classes that happen to share a name across different libraries
/// would collide — a pre-existing risk of the name-based design, widened
/// (not introduced) by giving the auto-dispose check a second reason to
/// consult this map.
Map<String, Set<String>> _prescanClassRegistry(CompilationUnit unit) {
  final registry = <String, Set<String>>{};
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final names = <String>{};
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        if (hasAnnotation(solidStateName, member.metadata)) {
          names.add(member.fields.variables.first.name.lexeme);
        }
      } else if (member is MethodDeclaration && member.isGetter) {
        if (hasAnnotation(solidStateName, member.metadata)) {
          names.add(member.name.lexeme);
        }
      }
    }
    if (names.isNotEmpty) registry[decl.name.lexeme] = names;
  }
  return registry;
}

/// Pre-scans every `ClassDeclaration` in [unit] and returns the cross-class
/// `@SolidQuery` name map (class name → `@SolidQuery` method names) — the
/// query counterpart of [_prescanClassRegistry]. Reuses
/// [_collectClassQueryNames] (the same per-class scan
/// `_collectAnnotatedClasses` already runs) so a class's query names are
/// derived identically whether consulted same-file or cross-file.
///
/// Kept as a SEPARATE registry from [_prescanClassRegistry] — never merged
/// into it — because a query name and a `@SolidState` field name are
/// consumed differently downstream: `value_rewriter.dart` appends `.value`
/// to a resolved `classRegistry` field but emits NO edit for a
/// `classQueryNames` call (see `_ValueRewriteVisitor._isCrossClassQueryCall`).
/// Mixing the two maps would wrongly append `.value` to a bare
/// `viewModel.customers` tear-off read.
Map<String, Set<String>> _prescanClassQueryNames(CompilationUnit unit) {
  final registry = <String, Set<String>>{};
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final names = _collectClassQueryNames(decl);
    if (names.isNotEmpty) registry[decl.name.lexeme] = names;
  }
  return registry;
}

/// Pre-scans every `ClassDeclaration` in [unit] and returns the cross-class
/// **type-text** map (class name → field/getter name → declared type text).
/// Parallel to [_prescanClassRegistry] — the same scan but with the
/// declared type peeled out. Consumed by `emitQuerySourceField` to emit the
/// Record element type for a `@SolidQuery` cross-class dep that reaches a
/// sibling class's `@SolidState` field/getter through an `@SolidEnvironment`
/// receiver.
///
/// Type-less declarations (no annotation on a field, no return type on a
/// getter) are stored as the empty string — the emitter throws a clear
/// `CodeGenerationError` at use time so the offending member can be named in
/// the diagnostic.
Map<String, Map<String, String>> _prescanClassFieldTypes(
  CompilationUnit unit,
) {
  final registry = <String, Map<String, String>>{};
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final types = <String, String>{};
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        if (!hasAnnotation(solidStateName, member.metadata)) continue;
        final name = member.fields.variables.first.name.lexeme;
        types[name] = member.fields.type?.toSource() ?? '';
      } else if (member is MethodDeclaration && member.isGetter) {
        if (!hasAnnotation(solidStateName, member.metadata)) continue;
        types[member.name.lexeme] = member.returnType?.toSource() ?? '';
      }
    }
    if (types.isNotEmpty) registry[decl.name.lexeme] = types;
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
      if (!hasAnnotation(solidStateName, member.metadata)) continue;
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
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Set<String> classRegistryShadowedNames,
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
    // Origin-qualified counterparts (issue #110), same exclude-self
    // discipline as the two flat views above.
    final crossClassRegistryOrigins =
        Map<String, Map<String, Set<String>>>.from(classRegistryOrigins)
          ..remove(selfClass);
    final crossClassCollectionFieldsOrigins =
        Map<String, Map<String, Set<String>>>.from(
          classCollectionFieldsOrigins,
        )..remove(selfClass);
    final crossClassShadowedNames = Set<String>.from(
      classRegistryShadowedNames,
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
    final widgetBoundCtorNames = _collectWidgetBoundCtorNames(decl);
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
          classRegistryOrigins: crossClassRegistryOrigins,
          classCollectionFieldsOrigins: crossClassCollectionFieldsOrigins,
          classRegistryShadowedNames: crossClassShadowedNames,
          environmentFields: environmentFieldsForBody,
          collectionFields: collectionFieldsSeen,
          widgetBoundFields: widgetBoundCtorNames,
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
          classRegistryOrigins: crossClassRegistryOrigins,
          classCollectionFieldsOrigins: crossClassCollectionFieldsOrigins,
          classRegistryShadowedNames: crossClassShadowedNames,
          environmentFields: environmentFieldsForBody,
          collectionFields: collectionFieldsSeen,
          widgetBoundFields: widgetBoundCtorNames,
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
          classRegistryOrigins: crossClassRegistryOrigins,
          classCollectionFieldsOrigins: crossClassCollectionFieldsOrigins,
          classRegistryShadowedNames: crossClassShadowedNames,
          environmentFields: environmentFieldsForBody,
          collectionFields: collectionFieldsSeen,
          widgetBoundFields: widgetBoundCtorNames,
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
    if (!hasAnnotation(solidEnvironmentName, member.metadata)) continue;
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

/// Per-class widget-bound ctor field names — the names that must be rewritten
/// from `field` to `widget.field` inside reactive-member bodies that move from
/// the source `StatelessWidget` into the lowered `State<X>`. Only meaningful
/// for `StatelessWidget` classes; plain classes and existing `State<X>`
/// subclasses have no Widget/State split and pass the empty default through.
Set<String> _collectWidgetBoundCtorNames(ClassDeclaration decl) {
  if (classKindOf(decl) != ClassKind.statelessWidget) return const <String>{};
  return collectWidgetBoundNames(
    decl.members.whereType<ConstructorDeclaration>(),
  );
}

/// Returns a TYPE-RESOLVED [CompilationUnit] for the build input when one
/// can be obtained, falling back to [parsedFallback] otherwise.
///
/// `buildStep.resolver.libraryFor` returns a fully-resolved `LibraryElement`
/// (analyzer forces type resolution at this call). `astNodeFor(anyElement,
/// resolve: true)` on any element from that library yields a resolved
/// declaration node whose enclosing `CompilationUnit` has `Expression.
/// staticType` populated throughout. The first available anchor is used
/// (classes are preferred — they almost always exist when `@Solid*`
/// annotations are present); when none is available the function returns
/// the [parsedFallback] AST unchanged.
///
/// `compilationUnitFor` alone is not equivalent: it calls
/// `session.getParsedUnit` and returns a parsed-but-unresolved unit. The
/// resolved variant is needed for type-driven predicates downstream.
Future<CompilationUnit> _resolveUnit(
  BuildStep buildStep,
  CompilationUnit parsedFallback,
) async {
  try {
    final library = await buildStep.resolver.libraryFor(
      buildStep.inputId,
      allowSyntaxErrors: true,
    );
    // `astNodeFor` takes a `Fragment` (the per-file declaration-level
    // element). The library's defining-file fragment is
    // available as `library.firstFragment` (a `LibraryFragment`); passing
    // it with `resolve: true` returns the resolved `CompilationUnit` for
    // that file directly. Falls back to the parsed AST if the resolver
    // returns null (rare; happens for elements sourced from summaries).
    final node = await buildStep.resolver.astNodeFor(
      library.firstFragment,
      resolve: true,
    );
    if (node is CompilationUnit) return node;
    final unit = node?.thisOrAncestorOfType<CompilationUnit>();
    return unit ?? parsedFallback;
  } on Object {
    // Defensive: any resolver error (asset not readable, transitive
    // analyzer failure on an import, …) falls back to the parsed AST. The
    // surfaced effect is that type-aware predicates degrade to the
    // pre-fix textual heuristics for this one file.
    return parsedFallback;
  }
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
  Map<String, Map<String, String>> classFieldTypes,
  Map<String, Set<String>> crossClassFieldTypeOriginUris,
  AssetId inputId,
  String source,
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Set<String> classRegistryShadowedNames,
  Map<String, Set<String>> classQueryNames,
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins,
  Set<String> classQueryNamesShadowedNames,
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
          classFieldTypes,
          source,
          classRegistryOrigins,
          classCollectionFieldsOrigins,
          classRegistryShadowedNames,
          classQueryNames,
          classQueryNamesOrigins,
          classQueryNamesShadowedNames,
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
  // Synthesize imports for cross-class signal types named in
  // `@SolidQuery`-synthesized Record-Computed sources. Dedup against
  // source-side imports by resolved `AssetId` — a relative `'types.dart'`
  // and the synthesized `package:<self>/.../types.dart` refer to the
  // same asset and must collapse to one import.
  final sourceImportAssets = <AssetId>{
    for (final uri in sourceDirectives.keys)
      ?_resolveImportToSourceAsset(uri, inputId),
  };
  final extraImports = <String>{
    for (final annotated in annotatedClasses)
      if (annotated.queries.any(
        (q) => q.trackedCrossClassSignalNames.isNotEmpty,
      ))
        ..._synthesizeExtraImports(
          annotated,
          classFieldTypes,
          crossClassFieldTypeOriginUris,
          sourceDirectives,
          sourceImportAssets,
          inputId,
        ),
  };
  final imports = computeOutputImports(
    sourceUris,
    addSolidart: results.any(
      (r) => r.solidartNames.any(solidartNames.contains),
    ),
    addProvider: annotatedClasses.any((c) => c.environments.isNotEmpty),
    referencesSolidAnnotations: referencesSolidAnnotations,
    extraImports: extraImports,
  );
  // `untracked(...)` (passed through verbatim from source, like
  // `.environment<T>()`) collides with the `solid_annotations` `untracked` stub
  // only when a file keeps BOTH imports — `solid_annotations` retained (a class
  // emits `Disposable` / uses `.environment<T>()`) and `flutter_solidart` added.
  // Then hide `untracked` from `solid_annotations` so the call binds to the
  // runtime function. The body scan (cf. `_environmentExtensionRef` for
  // verbatim-passthrough constructs) runs only when both imports are present.
  final keepsSolidAnnotations = imports.any(
    (u) => u.startsWith(solidAnnotationsUriPrefix),
  );
  final hideUntrackedFromAnnotations =
      keepsSolidAnnotations &&
      imports.contains(flutterSolidartUri) &&
      _untrackedCallRef.hasMatch(body);
  final importBlock = imports
      .map((u) {
        final directive = sourceDirectives[u] ?? "import '$u';";
        if (hideUntrackedFromAnnotations &&
            u.startsWith(solidAnnotationsUriPrefix)) {
          return _hideCombinator(directive, 'untracked');
        }
        return directive;
      })
      .join('\n');

  final combined = '$importBlock\n\n$body\n';
  // Inject `dispose: (context, provider) => provider.dispose()` into every
  // `Provider(...)`, `Provider<T>(...)`, and `.environment<T>(...)` call site
  // that omits `dispose:`. Runs before `addConstAtCallSites` so the injected
  // closure (a `FunctionExpression`, never const-eligible) is part of the
  // argument list when const promotion evaluates const-eligibility.
  final withDispose = addProviderDisposeAtCallSites(
    combined,
    classRegistry: classRegistry,
  );
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

/// Adds a `hide <name>` combinator before the `;` of an `import '...';`
/// directive, keeping a SINGLE combinator (two `show`/`hide` clauses warn
/// `multiple_combinators`, fatal under `--fatal-infos`):
///   * no combinator      → append `hide <name>`
///   * existing `hide ...` → merge: `hide ..., <name>`
///   * existing `show`/`as`→ leave unchanged (name not exposed / import prefixed)
///
/// The combinator scan looks only at the text after the quoted URI, so a path
/// segment like `/show.dart` is never mistaken for a combinator.
String _hideCombinator(String directive, String name) {
  final trimmed = directive.trimRight();
  if (!trimmed.endsWith(';')) return directive;
  final beforeSemi = trimmed.substring(0, trimmed.length - 1).trimRight();
  final firstQuote = beforeSemi.indexOf("'");
  final tail = firstQuote >= 0
      ? beforeSemi.substring(beforeSemi.indexOf("'", firstQuote + 1) + 1)
      : beforeSemi;
  if (_showOrAsCombinatorRef.hasMatch(tail)) return directive;
  if (_hideCombinatorRef.hasMatch(tail)) return '$beforeSemi, $name;';
  return '$beforeSemi hide $name;';
}

/// Returns a [RewriteResult] for [c]: a verbatim slice when the class has
/// no reactive annotations, otherwise the lowered output of [_rewriteClass].
RewriteResult _resultForClass(
  _AnnotatedClass c,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, String>> classFieldTypes,
  String source,
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Set<String> classRegistryShadowedNames,
  Map<String, Set<String>> classQueryNames,
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins,
  Set<String> classQueryNamesShadowedNames,
) {
  if (c.hasNoAnnotations) {
    // A no-annotation class can still be a PURE CONSUMER of a registered
    // class's reactive members through a plain instance/constructor field
    // (the common Flutter DI shape). Whole-file [lowerPureConsumers] only
    // runs when NO class in the file is annotated; in a MIXED file this
    // per-class lowering is the only path that reaches such a consumer, so a
    // cross-class read/write (e.g. `vm.query = value`) still lowers instead
    // of silently emitting `assignment_to_final` on the generated Signal.
    final lowered = lowerPureConsumerClass(
      c.decl,
      source,
      classRegistry: classRegistry,
      classCollectionFields: classCollectionFields,
      classRegistryOrigins: classRegistryOrigins,
      classCollectionFieldsOrigins: classCollectionFieldsOrigins,
      classRegistryShadowedNames: classRegistryShadowedNames,
      classQueryNames: classQueryNames,
      classQueryNamesOrigins: classQueryNamesOrigins,
      classQueryNamesShadowedNames: classQueryNamesShadowedNames,
    );
    return (
      text: lowered.text,
      // A placed `SignalBuilder` wrap needs `flutter_solidart` in the output
      // import block (keyed off `solidartNames` in `_renderOutput`); a
      // `.value`-only lowering introduces no new identifier and needs none.
      solidartNames: lowered.emittedSignalBuilder
          ? const {'SignalBuilder'}
          : const <String>{},
      emitsDisposable: false,
      constCtorNames: const <String>{},
    );
  }
  return _rewriteClass(
    c.decl,
    c.fields,
    c.getters,
    c.effects,
    c.queries,
    c.environments,
    classRegistry,
    classCollectionFields,
    classFieldTypes,
    source,
    classRegistryOrigins,
    classCollectionFieldsOrigins,
    classRegistryShadowedNames,
    classQueryNames,
    classQueryNamesOrigins,
    classQueryNamesShadowedNames,
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
  Map<String, Map<String, String>> classFieldTypes,
  String source,
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Set<String> classRegistryShadowedNames,
  Map<String, Set<String>> classQueryNames,
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins,
  Set<String> classQueryNamesShadowedNames,
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
        classFieldTypes,
        source,
        classRegistryOrigins: classRegistryOrigins,
        classCollectionFieldsOrigins: classCollectionFieldsOrigins,
        classRegistryShadowedNames: classRegistryShadowedNames,
        classQueryNames: classQueryNames,
        classQueryNamesOrigins: classQueryNamesOrigins,
        classQueryNamesShadowedNames: classQueryNamesShadowedNames,
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
        classFieldTypes,
        source,
        classRegistryOrigins: classRegistryOrigins,
        classCollectionFieldsOrigins: classCollectionFieldsOrigins,
        classRegistryShadowedNames: classRegistryShadowedNames,
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
        classFieldTypes,
        source,
        classRegistryOrigins: classRegistryOrigins,
        classCollectionFieldsOrigins: classCollectionFieldsOrigins,
        classRegistryShadowedNames: classRegistryShadowedNames,
        classQueryNames: classQueryNames,
        classQueryNamesOrigins: classQueryNamesOrigins,
        classQueryNamesShadowedNames: classQueryNamesShadowedNames,
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
/// current source file, each type name in [extraWantedTypes] (the types
/// created at a `Provider(...)` / `.environment<T>()` call site in this
/// file — see [collectProviderCreatedTypeNames]), OR the declared type name
/// of any class's instance field / constructor parameter in this file (the
/// plain constructor-injection DI shape — see issue #104), walk the imported
/// `source/<path>.dart` file(s) via `BuildStep.resolver.compilationUnitFor`
/// and merge any `@SolidState` members of the matching class declaration
/// into [classRegistry] (and the collection-subset into
/// [classCollectionFields]).
///
/// The two registries are mutated in place. Same-file types take precedence:
/// when a type name is already present, the cross-file pass does NOT
/// overwrite it (in-file source is always the source of truth for the
/// current build).
///
/// A simple name this unit ALSO declares itself (class/enum/mixin/…) no
/// longer removes the name from the wanted set before the import walk (issue
/// #110 — it used to, dropping any foreign class of that name from the
/// registry entirely, silently losing its reactivity). The import walk now
/// always searches; a match found under a locally-shadowed name (or a name
/// two-plus distinct imports resolve to different classes for) is
/// registered QUALIFIED, by origin, into [classRegistryOrigins] /
/// [classCollectionFieldsOrigins] rather than the flat [classRegistry] /
/// [classCollectionFields] — see the finalize pass at the end of this
/// function and `value_rewriter.dart`'s [_ValueRewriteVisitor.
/// _fieldsForCrossClassName] for how a flagged name resolves at rewrite
/// time (a mandatory tier-1 library-URI match). Each import's `show`/`hide`
/// combinators are still honored, so an import cannot be credited as a
/// name's source when it explicitly excludes that name (see
/// [_importExposesName]).
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
  Map<String, Map<String, String>> classFieldTypes,
  Map<String, Set<String>> crossClassFieldTypeOriginUris,
  Set<String> extraWantedTypes,
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Set<String> classRegistryShadowedNames,
  Map<String, Set<String>> classQueryNames,
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins,
  Set<String> classQueryNamesShadowedNames,
) async {
  // Walk every `@SolidEnvironment` field declaration in the unit. The
  // builder pre-scan does NOT pre-build env-field models — the readers do
  // that downstream — so this loop reads metadata directly off the AST.
  // Resolution is keyed on the declared `typeText`; same-file types already
  // present in [classRegistry] are skipped (the same-file pass is the
  // source of truth there).
  final wantedTypes = <String>{};
  // Computed up front (issue #108 fix review finding 1; repurposed by issue
  // #110). A name [unit] itself declares always shadows a same-name import
  // for ORDINARY (unqualified) name resolution — Dart's own rule — no
  // matter how many hops away the import lives. Before issue #110 this set
  // was used to strip such names from `wantedTypes` before the import walk
  // even started, so a foreign class sharing the name was never looked up
  // at all and its reactivity silently lost (see the
  // `cross_file_super_param_one_hop_local_shadow` fixture). It is now
  // consulted only by the finalize pass at the end of this function, AFTER
  // the walk below has had a chance to find and qualify any such foreign
  // class by origin — see [classRegistryOrigins].
  final declaredInUnit = _collectDeclaredTypeNames(unit);
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    for (final member in decl.members) {
      if (member is! FieldDeclaration) continue;
      if (!hasAnnotation(solidEnvironmentName, member.metadata)) continue;
      final type = member.fields.type;
      if (type == null) continue;
      final typeText = type.toSource();
      if (typeText.isEmpty) continue;
      if (classRegistry.containsKey(typeText)) continue;
      wantedTypes.add(typeText);
    }
  }
  for (final typeText in extraWantedTypes) {
    if (classRegistry.containsKey(typeText)) continue;
    wantedTypes.add(typeText);
  }
  // Additionally seed `wantedTypes` from the declared type names of every
  // class's instance fields and constructor parameters — the plain
  // constructor-injection DI shape (`CustomersRepository({required
  // AuthRepository authRepository})`, `final AuthRepository
  // _authRepository;`) has no `@SolidEnvironment` field and creates nothing
  // at a `Provider(...)` / `.environment<T>()` call site, so neither rule
  // above ever seeds it — see issue #104. Candidates are annotation-blind
  // simple type names, exactly like the two seeding rules above; a name that
  // doesn't match any `@SolidState`-bearing class among the resolved imports
  // below is harmless — the import walk only writes a `classRegistry` entry
  // when it finds `@SolidState` members on the matching class. Generic type
  // arguments are seeded recursively (`List<AuthRepository>` seeds both
  // `List` and `AuthRepository`, `Map<String, List<AuthRepository>>` seeds
  // all three) via [_seedWantedTypeRecursive] — `List`/`Map`/`String` are
  // filtered out by [_coreSdkTypeNames] there, so only the payload type
  // reaches [wantedTypes]. This enables the resolved-type-driven cross-class
  // rewrite tiers in `value_rewriter.dart` to fire on collection-derived
  // receivers whose static type resolves to the payload class (e.g. a
  // `for (final c in repos) { c.field }` loop variable, or `repos.first`) —
  // see issue #104 fix review, finding 4.
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        // `static` fields ARE seeded (issue #106 residual gap survey, GAP
        // 2): a singleton-holder shape (`static final AuthRepository
        // instance = …;`, consumed elsewhere as `Holder.instance.session`)
        // is exactly as valid a DI source as an instance field. The
        // original `isStatic` skip here carried no stated rationale in
        // #104/#105's history — it silently mirrored `@SolidState`'s OWN
        // instance-only restriction (Section 3.1), which is a rule about
        // what `@SolidState` may annotate, not about what this unrelated
        // seeding loop may harvest a type name from.
        final type = member.fields.type;
        if (type is! NamedType) continue;
        _seedWantedTypeRecursive(type, wantedTypes, classRegistry);
      } else if (member is ConstructorDeclaration) {
        for (final param in member.parameters.parameters) {
          final inner = param is DefaultFormalParameter
              ? param.parameter
              : param;
          final TypeAnnotation? paramType;
          if (inner is SimpleFormalParameter) {
            paramType = inner.type;
          } else if (inner is FieldFormalParameter) {
            paramType = inner.type;
          } else if (inner is SuperFormalParameter) {
            // The explicit-type-annotation shape (`Foo(AuthRepository
            // super.repo)`) is recoverable syntactically: `inner.type` is
            // populated straight from the source annotation, same as the
            // two branches above. The far more common bare-shorthand form
            // (`super.repo`, no type written) carries NO type annotation in
            // the source at all — but on the RESOLVED path (this file has
            // at least one `@Solid*` annotation or a provider hint of its
            // own, so `unit` here is a fully-resolved `CompilationUnit`),
            // `SuperFormalParameter.declaredFragment.element.type` IS
            // populated even without a written annotation (issue #106
            // residual gap survey, GAP 3; verified empirically against
            // `package:analyzer`). `_seedFromResolvedSuperFormal` is the
            // fallback for exactly that case.
            //
            // The resolved fallback above is MOOT for a pure consumer whose
            // ONLY link to the cross-file class is a bare `super.x`: such a
            // file has no `@Solid*` annotation and no provider hint, so it
            // takes the no-annotation fast path's UNRESOLVED syntactic
            // probe first (`parsed.unit`, no `declaredFragment` available
            // either) — the resolved call above is a no-op there. Issue
            // #108 closes exactly that gap with a purely syntactic
            // counterpart, [_seedFromSyntacticSuperFormal]: it walks
            // [decl]'s own `extends` clause to find the superclass
            // declaration (locally or via this same import-walk
            // discipline, same-package-only — issue #108 fix review
            // finding 2), matches [inner] against the super-constructor
            // the enclosing constructor's initializer list targets, and
            // seeds the matched parameter's (or, for a `this.x` field
            // formal, the same-named instance field's) declared type. When
            // the located superclass lives in another file entirely (the
            // common case: a pure consumer's own file rarely declares its
            // own base class), that file's declaration may itself only
            // reference the wanted type through ONE of ITS OWN imports —
            // [_populateCrossFileTypesOneHop] below is that one purposeful
            // extra hop (issue #108 fix review finding 1), not a general
            // transitive walk.
            paramType = inner.type;
            if (paramType == null) {
              // Finding 2 also cuts a real perf corner here: skip the
              // syntactic walk entirely once the resolved path already
              // found this parameter's type. The syntactic walk exists
              // ONLY to cover the unresolved fast path where the resolved
              // call is a guaranteed no-op (see above); running it anyway
              // after a successful resolution is a wasted import-and-parse
              // walk for a name already seeded — and, left unconditional,
              // this walk fires for EVERY bare `super.` parameter on the
              // RESOLVED path too, including the ubiquitous `{super.key}`
              // on a Flutter widget, where it would otherwise chase
              // `StatefulWidget`/`State` into `package:flutter` itself.
              final resolvedHere = _seedFromResolvedSuperFormal(
                inner,
                wantedTypes,
                classRegistry,
              );
              if (!resolvedHere) {
                final hop = await _seedFromSyntacticSuperFormal(
                  inner,
                  decl,
                  member,
                  unit,
                  step.inputId,
                  step,
                  wantedTypes,
                  classRegistry,
                );
                if (hop != null) {
                  await _populateCrossFileTypesOneHop(
                    hop.$1,
                    hop.$2,
                    step,
                    wantedTypes,
                    classRegistry,
                    classCollectionFields,
                    classFieldTypes,
                    crossClassFieldTypeOriginUris,
                    classRegistryOrigins,
                    classCollectionFieldsOrigins,
                    classQueryNames,
                    classQueryNamesOrigins,
                  );
                }
              }
            }
          } else {
            paramType = null;
          }
          if (paramType is! NamedType) continue;
          _seedWantedTypeRecursive(paramType, wantedTypes, classRegistry);
        }
      }
    }
  }
  // A simple name this unit itself declares as a class/enum/mixin/etc. no
  // longer removes that name from `wantedTypes` (issue #110 — see this
  // function's doc comment). `wantedTypes` may still be empty here (nothing
  // needed cross-file resolution at all), in which case the walk below is a
  // no-op.
  if (wantedTypes.isEmpty) return;

  for (final directive in unit.directives.whereType<ImportDirective>()) {
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
    _registerWantedClassesFrom(
      imported,
      assetId,
      directive,
      step,
      wantedTypes,
      classRegistry,
      classCollectionFields,
      classFieldTypes,
      crossClassFieldTypeOriginUris,
      classRegistryOrigins,
      classCollectionFieldsOrigins,
      classQueryNames,
      classQueryNamesOrigins,
    );
  }

  // Finalize per-name ambiguity (issue #110). A name qualifies for
  // disambiguation — meaning the flat, name-keyed `classRegistry` /
  // `classCollectionFields` deliberately hold NO entry for it, forcing
  // every consumer through the origin-qualified `classRegistryOrigins` /
  // `classCollectionFieldsOrigins` side-maps instead — iff either (a)
  // `_registerWantedClassesFrom` (above, or via the one-hop extension)
  // found the name under two or more DISTINCT origins (a genuine
  // same-simple-name collision across this file's own imports), or (b)
  // this file ALSO declares its own top-level type under that name (the
  // shadowing scenario this issue exists to fix — previously handled by
  // dropping the name from `wantedTypes` before the walk even started, so
  // the foreign class's reactivity was lost outright rather than merely
  // qualified). Every OTHER name keeps its flat entry exactly as
  // `_registerWantedClassesFrom` wrote it — unconditionally unambiguous,
  // byte-identical to this generator's behavior before issue #110.
  for (final name in classRegistryOrigins.keys) {
    final origins = classRegistryOrigins[name]!;
    final isAmbiguous = origins.length > 1 || declaredInUnit.contains(name);
    if (!isAmbiguous) continue;
    classRegistryShadowedNames.add(name);
    classRegistry.remove(name);
    classCollectionFields.remove(name);
  }
  // Query counterpart of the finalize pass above — same ambiguity rule,
  // applied to [classQueryNamesOrigins] / [classQueryNames] instead. A
  // pure-query class (no `@SolidState` members at all) is registered ONLY
  // here — [classRegistryOrigins] never sees it — so this loop cannot be
  // skipped even when the loop above found nothing to strip.
  for (final name in classQueryNamesOrigins.keys) {
    final origins = classQueryNamesOrigins[name]!;
    final isAmbiguous = origins.length > 1 || declaredInUnit.contains(name);
    if (!isAmbiguous) continue;
    classQueryNamesShadowedNames.add(name);
    classQueryNames.remove(name);
  }
}

/// Scans [imported]'s top-level class declarations for names still present
/// in [wantedTypes], registering every match that carries at least one
/// `@SolidState` field or getter into [classRegistry] (and
/// [classCollectionFields] / [classFieldTypes] /
/// [crossClassFieldTypeOriginUris] alongside it). [directive] supplies the
/// `show`/`hide` combinators that gate whether [imported] may be credited
/// as [wantedTypes]'s source; [importedAssetId] anchors the field-type-
/// origin URI resolution below to [imported]'s own location, not the
/// original file being built.
///
/// Shared by [_populateCrossFileTypes]'s own directive walk and its one-hop
/// extension ([_populateCrossFileTypesOneHop], issue #108 fix review
/// finding 1) so both apply IDENTICAL registration rules — including the
/// "don't stop at the first same-named-but-unannotated decoy" discipline: a
/// match with zero `@SolidState` members contributes nothing.
///
/// [wantedTypes] is NEVER mutated here (issue #110 — it used to remove a
/// name as soon as one reactive match was found, which meant a SECOND
/// distinct class sharing that same simple name, reached through a LATER
/// import of the same file, was never even looked at). Every call site now
/// keeps searching every one of its own imports for every wanted name, so a
/// genuine same-simple-name collision across two distinct cross-file
/// classes is fully discovered — each origin recorded into
/// [classRegistryOrigins] / [classCollectionFieldsOrigins] — rather than
/// silently resolved to whichever import happened to be scanned first. This
/// is a bounded cost (this file's own import count, never transitive); a
/// name found in exactly one import — the overwhelming common case — pays
/// no extra cost beyond scanning the (typically short) remainder of the
/// import list.
///
/// [classRegistry] / [classCollectionFields] / [classFieldTypes] receive
/// EVERY match found, keyed by simple name only, exactly as before issue
/// #110 — including a match under a name that turns out to be ambiguous.
/// [_populateCrossFileTypes]'s finalize pass, which runs after every call
/// site here has contributed, is what strips such a name back out of
/// [classRegistry] / [classCollectionFields] once it recognizes the
/// ambiguity; this function does not need to know about that decision.
/// [classRegistryOrigins] / [classCollectionFieldsOrigins] accumulate every
/// match's fields keyed by BOTH simple name and origin URI
/// (`_sourceToLibAsset(importedAssetId).uri.toString()` — the same
/// asset-derived URI form [crossClassFieldTypeOriginUris] already uses),
/// unconditionally — this is the qualified data the finalize pass and
/// `value_rewriter.dart`'s tier-1 URI match need for a name it flags.
///
/// [classQueryNames] receives every matched class's `@SolidQuery` method
/// names — UNCONDITIONALLY, not gated on `scalarNames.isNotEmpty` like the
/// `@SolidState` registration above: a pure-query ViewModel (zero
/// `@SolidState` members) is exactly as valid a cross-instance query source
/// as one that also happens to own reactive state. [classQueryNamesOrigins]
/// is its origin-qualified counterpart (issue #110 parity), populated
/// unconditionally alongside it exactly like [classRegistryOrigins].
void _registerWantedClassesFrom(
  CompilationUnit imported,
  AssetId importedAssetId,
  ImportDirective directive,
  BuildStep step,
  Set<String> wantedTypes,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, String>> classFieldTypes,
  Map<String, Set<String>> crossClassFieldTypeOriginUris,
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Map<String, Set<String>> classQueryNames,
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins,
) {
  for (final decl in imported.declarations) {
    if (decl is! ClassDeclaration) continue;
    final className = decl.name.lexeme;
    if (!wantedTypes.contains(className)) continue;
    if (!_importExposesName(directive, className)) continue;
    // Computed once per matched class and shared by both the state and
    // query origin maps below — same asset-derived URI form
    // [crossClassFieldTypeOriginUris] already uses.
    final originUri = _sourceToLibAsset(importedAssetId).uri.toString();
    final queryNamesFound = _collectClassQueryNames(decl);
    if (queryNamesFound.isNotEmpty) {
      (classQueryNames[className] ??= <String>{}).addAll(queryNamesFound);
      // Origin-qualified counterpart (issue #110 parity) — recorded
      // unconditionally for every match, ambiguous or not; see this
      // function's doc comment and [_populateCrossFileTypes]'s finalize
      // pass.
      (classQueryNamesOrigins[className] ??=
              <String, Set<String>>{})[originUri] =
          queryNamesFound;
    }
    final scalarNames = <String>{};
    final collectionNames = <String>{};
    final fieldTypeTexts = <String, String>{};
    for (final member in decl.members) {
      if (member is FieldDeclaration) {
        if (!hasAnnotation(solidStateName, member.metadata)) continue;
        final variable = member.fields.variables.first;
        final fieldName = variable.name.lexeme;
        scalarNames.add(fieldName);
        fieldTypeTexts[fieldName] = member.fields.type?.toSource() ?? '';
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
        if (!hasAnnotation(solidStateName, member.metadata)) continue;
        scalarNames.add(member.name.lexeme);
        fieldTypeTexts[member.name.lexeme] =
            member.returnType?.toSource() ?? '';
      }
    }
    if (scalarNames.isNotEmpty) {
      classRegistry[className] = scalarNames;
      if (collectionNames.isNotEmpty) {
        classCollectionFields[className] = collectionNames;
      }
      if (fieldTypeTexts.isNotEmpty) {
        classFieldTypes[className] = fieldTypeTexts;
      }
      // Origin-qualified counterpart (issue #110) — recorded unconditionally
      // for every match, ambiguous or not; see this function's doc comment
      // and [_populateCrossFileTypes]'s finalize pass.
      (classRegistryOrigins[className] ??= <String, Set<String>>{})[originUri] =
          scalarNames;
      if (collectionNames.isNotEmpty) {
        (classCollectionFieldsOrigins[className] ??=
                <String, Set<String>>{})[originUri] =
            collectionNames;
      }
      // For each `@SolidState` field whose declared type is NOT declared
      // inside the same class file, capture the file's same-package import
      // URIs as candidate origins. The consumer's lib output will inject
      // these so the synthesized Record-Computed `Computed<(…, T, …)>`
      // resolves at lib-time even when the consumer's source never
      // textually references `T`.
      final declaredHere = _collectDeclaredTypeNames(imported);
      final localCandidateUris = <String>{};
      for (final innerDirective
          in imported.directives.whereType<ImportDirective>()) {
        final innerUri = innerDirective.uri.stringValue;
        if (innerUri == null) continue;
        final importedAsset = _resolveImportToSourceAsset(
          innerUri,
          importedAssetId,
        );
        if (importedAsset == null) continue;
        if (importedAsset.package != step.inputId.package) continue;
        if (!importedAsset.path.startsWith('source/')) continue;
        localCandidateUris.add(
          _sourceToLibAsset(importedAsset).uri.toString(),
        );
      }
      if (localCandidateUris.isNotEmpty) {
        for (final entry in fieldTypeTexts.entries) {
          final typeText = entry.value;
          if (typeText.isEmpty) continue;
          if (declaredHere.contains(typeText)) continue;
          (crossClassFieldTypeOriginUris[typeText] ??= <String>{}).addAll(
            localCandidateUris,
          );
        }
      }
    }
  }
}

/// One-hop extension of [_populateCrossFileTypes]'s cross-file registry
/// walk (issue #108 fix review finding 1): a name
/// [_seedFromSyntacticSuperFormal] derives from a superclass declared in
/// ANOTHER file than the one being scanned can only be declared in one of
/// TWO places — [hostUnit] itself (already covered by the main walk above,
/// since [hostUnit] is one of the scanned file's own imports and the main
/// walk visits it directly) or one of [hostUnit]'s OWN imports, a file the
/// scanned file never directly imports and the main walk therefore never
/// reaches. This function is that one additional hop: same registration
/// rule as the main walk ([_registerWantedClassesFrom]), anchored at
/// [hostUnit] / [hostAssetId] instead of the original file. Deliberately
/// NOT a general transitive walk — this function never calls itself, and
/// its only caller passes the immediate superclass's own host file, never
/// anything further removed.
///
/// Same-package guard (issue #108 fix review finding 2): a cross-package
/// import (e.g. `package:flutter/...`) can never host this package's
/// `@SolidState` classes, so it's skipped before any read or parse. The
/// pre-existing main walk above carries no such restriction (out of scope
/// for this fix — it seeds from names written directly in the scanned
/// file, never from a syntactically-derived superclass chase), but this
/// one-hop extension exists ONLY to serve the superclass seeder, which
/// itself only ever locates a same-package superclass in the first place.
///
/// Consuming-unit shadow (issue #108 fix review addendum, finding 1;
/// repurposed by issue #110): a name the ORIGINAL scanned file declares
/// locally (e.g. its own plain `class Foo`) used to be stripped from
/// [wantedTypes] before this function even ran, so a match found here
/// through [hostUnit]'s imports was never registered at all — silently
/// dropping a genuinely reactive foreign class's fields (see the
/// `cross_file_super_param_one_hop_local_shadow` fixture). This function no
/// longer applies that guard: a match found here is registered exactly like
/// any other, and [_populateCrossFileTypes]'s finalize pass — which runs
/// once, after every one-hop call site here has already contributed to the
/// SAME [classRegistryOrigins] / [classCollectionFieldsOrigins] instances —
/// is what flags the name as ambiguous against the original file's own
/// declared names, qualifying rather than discarding the registration.
Future<void> _populateCrossFileTypesOneHop(
  CompilationUnit hostUnit,
  AssetId hostAssetId,
  BuildStep step,
  Set<String> wantedTypes,
  Map<String, Set<String>> classRegistry,
  Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, String>> classFieldTypes,
  Map<String, Set<String>> crossClassFieldTypeOriginUris,
  Map<String, Map<String, Set<String>>> classRegistryOrigins,
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins,
  Map<String, Set<String>> classQueryNames,
  Map<String, Map<String, Set<String>>> classQueryNamesOrigins,
) async {
  // Same local-shadowing discipline the main walk once applied to the
  // original file, applied here relative to [hostUnit] itself (distinct
  // from the original file — see the doc comment above): a name [hostUnit]
  // declares directly can never be the wanted type's source via one of ITS
  // OWN imports, because within [hostUnit]'s own scope that name
  // unambiguously resolves to [hostUnit]'s local declaration, full stop —
  // this is ordinary Dart name resolution, not an issue-#110-style
  // cross-FILE collision. In practice this is always already a no-op, since
  // a name declared directly in [hostUnit] would already have been found by
  // the main walk's own scan of [hostUnit]'s declarations before this
  // function is ever reached. Kept for defense and to make the discipline
  // explicit.
  wantedTypes.removeAll(_collectDeclaredTypeNames(hostUnit));
  if (wantedTypes.isEmpty) return;

  for (final directive in hostUnit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri == null || uri.startsWith('dart:')) continue;
    final assetId = _resolveImportToSourceAsset(uri, hostAssetId);
    if (assetId == null) continue;
    if (assetId.package != step.inputId.package) continue;
    if (!assetId.path.endsWith('.dart')) continue;
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
    _registerWantedClassesFrom(
      imported,
      assetId,
      directive,
      step,
      wantedTypes,
      classRegistry,
      classCollectionFields,
      classFieldTypes,
      crossClassFieldTypeOriginUris,
      classRegistryOrigins,
      classCollectionFieldsOrigins,
      classQueryNames,
      classQueryNamesOrigins,
    );
  }
}

/// Computes the `extraImports` contribution from a single annotated class —
/// the cross-class signal types its `@SolidQuery` bodies name in their
/// synthesized Record-Computed sources. Imports are returned in
/// relative-lib form (so `prefer_relative_imports` stays satisfied) and
/// dedup'd against the consumer's source-side imports by resolved AssetId.
Iterable<String> _synthesizeExtraImports(
  _AnnotatedClass annotated,
  Map<String, Map<String, String>> classFieldTypes,
  Map<String, Set<String>> crossClassFieldTypeOriginUris,
  Map<String, String> sourceDirectives,
  Set<AssetId> sourceImportAssets,
  AssetId inputId,
) sync* {
  final envTypeByField = {
    for (final env in annotated.environments) env.fieldName: env.typeText,
  };
  for (final query in annotated.queries) {
    for (final dep in query.trackedCrossClassSignalNames) {
      final envType = envTypeByField[dep.envField];
      if (envType == null) continue;
      final typeText = classFieldTypes[envType]?[dep.name];
      if (typeText == null || typeText.isEmpty) continue;
      final uris = crossClassFieldTypeOriginUris[typeText];
      if (uris == null) continue;
      for (final u in uris) {
        if (sourceDirectives.containsKey(u)) continue;
        final asset = _resolveImportToSourceAsset(u, inputId);
        if (asset != null && sourceImportAssets.contains(asset)) continue;
        yield asset != null && asset.package == inputId.package
            ? _relativeLibImportFrom(inputId, asset)
            : u;
      }
    }
  }
}

/// Returns the set of top-level type names declared in [unit] — classes,
/// enums, mixins, typedefs, extensions. Used by [_populateCrossFileTypes] to
/// distinguish "this type lives in the same file I'm scanning (no import
/// needed downstream)" from "this type comes from one of the file's imports
/// and the downstream consumer must import it to resolve `Computed<(…, T,
/// …)>` in lib".
Set<String> _collectDeclaredTypeNames(CompilationUnit unit) {
  final names = <String>{};
  for (final decl in unit.declarations) {
    if (decl is ClassDeclaration) names.add(decl.name.lexeme);
    if (decl is EnumDeclaration) names.add(decl.name.lexeme);
    if (decl is MixinDeclaration) names.add(decl.name.lexeme);
    if (decl is ExtensionDeclaration) {
      final n = decl.name?.lexeme;
      if (n != null) names.add(n);
    }
    if (decl is FunctionTypeAlias) names.add(decl.name.lexeme);
    if (decl is GenericTypeAlias) names.add(decl.name.lexeme);
  }
  return names;
}

/// True when [directive]'s `show`/`hide` combinators (if any) allow [name]
/// to be brought into scope by that import — i.e. the directive cannot be
/// [name]'s source when this returns false. An import may carry multiple
/// combinators (`show A hide B` is legal, if unusual); ALL of them must
/// agree the name is visible.
///
/// Used by [_populateCrossFileTypes]'s import walk so a `hide Foo` (or a
/// `show` list that excludes `Foo`) is honored — mirrors Dart's own
/// combinator semantics and protects every seeding path (same-file
/// `@SolidEnvironment` fields, `Provider(...)`/`.environment<T>()` call
/// sites, and the constructor-injection seeding added for issue #104) from
/// misattributing a same-simple-name class the import explicitly excludes.
bool _importExposesName(ImportDirective directive, String name) {
  for (final combinator in directive.combinators) {
    if (combinator is ShowCombinator) {
      if (!combinator.shownNames.any((id) => id.name == name)) return false;
    } else if (combinator is HideCombinator) {
      if (combinator.hiddenNames.any((id) => id.name == name)) return false;
    }
  }
  return true;
}

/// `dart:core` / `dart:async` simple type names a user class would never
/// legitimately shadow. Checked by [_seedWantedTypeRecursive] before adding
/// a candidate to `wantedTypes` in the constructor-injection / instance-
/// field seeding loop added for issue #104 (the two PRE-EXISTING seeding
/// paths — `@SolidEnvironment` fields and `Provider`/`.environment<T>()`
/// call sites — are left untouched, per finding 5 of the fix review: those
/// are already annotation- or call-site-scoped and rarely fire on SDK
/// names).
///
/// Without this filter, nearly every annotated file would seed `String`,
/// `int`, `bool`, etc. from ordinary field/parameter declarations, defeating
/// the `wantedTypes.isEmpty` early return below and forcing a wasted
/// resolve-and-scan of every import for a name no import will ever satisfy
/// (the SDK carries no `@SolidState` annotations).
const Set<String> _coreSdkTypeNames = {
  'int',
  'double',
  'num',
  'bool',
  'String',
  'List',
  'Map',
  'Set',
  'Iterable',
  'Iterator',
  'Object',
  'Function',
  'Never',
  'Null',
  'dynamic',
  'Future',
  'FutureOr',
  'Stream',
  'StreamSubscription',
  'StreamController',
  'Duration',
  'DateTime',
  'Symbol',
  'Type',
  'BigInt',
  'RegExp',
  'RegExpMatch',
  'Uri',
  'StringBuffer',
  'StringSink',
  'Timer',
  'Comparable',
  'Pattern',
  'Match',
  'Runes',
  'StackTrace',
  'Exception',
  'Error',
  'Record',
  'Completer',
  'Zone',
  'Sink',
  'EventSink',
  'WeakReference',
  'Expando',
};

/// Adds [type]'s simple name — and, recursively, the simple name of every
/// generic type argument at every nesting level — to [wantedTypes], subject
/// to the same two guards the pre-existing seeding call sites apply inline:
/// skip names already resolved in [classRegistry], and (new for issue #104
/// finding 4/5) skip [_coreSdkTypeNames].
///
/// `List<AuthRepository>` seeds `AuthRepository` (not `List`, filtered);
/// `Map<String, List<AuthRepository>>` seeds only `AuthRepository` (both
/// `Map` and `String` are filtered, `List` is filtered, `AuthRepository`
/// survives). A candidate that matches nothing on the subsequent import walk
/// is harmless — see the loop's own doc comment.
void _seedWantedTypeRecursive(
  NamedType type,
  Set<String> wantedTypes,
  Map<String, Set<String>> classRegistry,
) {
  final typeText = type.name.lexeme;
  if (!_coreSdkTypeNames.contains(typeText) &&
      !classRegistry.containsKey(typeText)) {
    wantedTypes.add(typeText);
  }
  final args = type.typeArguments?.arguments;
  if (args == null) return;
  for (final arg in args) {
    if (arg is NamedType) {
      _seedWantedTypeRecursive(arg, wantedTypes, classRegistry);
    }
  }
}

/// Ensures the `SignalBuilder` identifier [lowerPureConsumers] (issue #106
/// residual gap survey, GAP 1) reported emitting via `emittedSignalBuilder`
/// actually resolves in [text]. Callers already checked that flag — never a
/// substring scan of [text] for `SignalBuilder(`, which both risks a
/// false-positive on a preserved source comment and can't tell an EXPOSED
/// existing import from a RESTRICTED one.
///
/// Three cases, keyed on whether [unit] already imports `flutter_solidart`
/// and, if so, whether its combinators actually expose the name:
///  * no `flutter_solidart` import at all → splice in a clean one
///    ([_ensureFlutterSolidartImport], pre-existing behavior).
///  * an import exists and already exposes `SignalBuilder`
///    ([_importExposesName], reused from the cross-file registry walk) →
///    no-op. This is the common case: an import added fresh by this same
///    function always exposes every name, so only a HAND-WRITTEN `show`/
///    `hide` on a pre-existing import can narrow it.
///  * an import exists but does NOT expose `SignalBuilder` (a `show` list
///    that omits it, or a `hide SignalBuilder`) — e.g. a file that already
///    does `import '…/flutter_solidart.dart' show Signal;` for some
///    unrelated hand-rolled signal before ever gaining a pure-consumer
///    widget read — → repair that import's combinators in place
///    ([_repairImportToExposeName]) rather than adding a second import of
///    the same URI (which `dart analyze` would flag as `duplicate_import`).
///
/// Known, accepted gap: an `as`-PREFIXED existing import (`import '…' as
/// sa;`) is not detected as non-exposing — [_importExposesName] only
/// inspects `show`/`hide` combinators, not prefixes — so a file whose only
/// `flutter_solidart` import is aliased would still emit an unresolvable
/// bare `SignalBuilder(...)`. No reported real-world shape does this (the
/// project's own convention forbids import aliases), and every one of this
/// generator's OWN rewriters emits bare (unprefixed) `flutter_solidart`
/// identifiers, so the gap only bites a hand-aliased pre-existing import.
String _ensureSignalBuilderResolves(String text, CompilationUnit unit) {
  ImportDirective? existing;
  for (final directive in unit.directives.whereType<ImportDirective>()) {
    if (directive.uri.stringValue == flutterSolidartUri) {
      existing = directive;
      break;
    }
  }
  if (existing == null) return _ensureFlutterSolidartImport(text, unit);
  if (_importExposesName(existing, 'SignalBuilder')) return text;
  return _repairImportToExposeName(text, existing, 'SignalBuilder');
}

/// Splices [name] into [directive]'s combinators so it becomes visible,
/// using the combinator nodes' own AST offsets rather than a fragile textual
/// regex — robust regardless of whitespace/formatting:
///  * an existing `show` combinator gains `, <name>` after its last shown
///    name;
///  * an existing `hide` combinator loses `<name>` — the whole `hide`
///    clause is removed if [name] was its only hidden name, otherwise just
///    `<name>` (and its separating comma) is spliced out.
///
/// Only called after [_importExposesName] has already confirmed [directive]
/// does NOT expose [name], so exactly one of the two branches below applies
/// — an import with neither combinator, or with a `show`/`hide` that
/// already agrees the name is visible, would have made
/// [_importExposesName] return `true` and this function would never run.
/// Leaves [text] untouched (defensive fallback, not expected to be reached)
/// if neither combinator matches.
String _repairImportToExposeName(
  String text,
  ImportDirective directive,
  String name,
) {
  for (final combinator in directive.combinators) {
    if (combinator is ShowCombinator) {
      if (combinator.shownNames.any((id) => id.name == name)) continue;
      final last = combinator.shownNames.last;
      return '${text.substring(0, last.end)}, '
          '$name${text.substring(last.end)}';
    }
    if (combinator is HideCombinator) {
      final hidden = combinator.hiddenNames;
      final idx = hidden.indexWhere((id) => id.name == name);
      if (idx == -1) continue;
      if (hidden.length == 1) {
        return text.substring(0, combinator.offset) +
            text.substring(combinator.end);
      }
      if (idx == 0) {
        return text.substring(0, hidden[0].offset) +
            text.substring(hidden[1].offset);
      }
      return text.substring(0, hidden[idx - 1].end) +
          text.substring(hidden[idx].end);
    }
  }
  return text;
}

/// Ensures `package:flutter_solidart/flutter_solidart.dart` is imported in
/// [text] when no existing import of it is present at all. Called by
/// [_ensureSignalBuilderResolves] for that one case; the other two (an
/// existing import that already exposes the name, or one that needs
/// combinator repair) are handled directly there.
///
/// Unlike `_renderOutput`'s main annotated path, this no-annotation branch
/// never runs [computeOutputImports] against a freshly reassembled import
/// block — there is no per-class rewrite result to aggregate. This is a
/// narrow, text-level splice instead: [unit]'s import-directive offsets are
/// still valid against [text] because every edit the pure-consumer lowering
/// passes make lands inside a class member, strictly after the last import
/// directive — so the import section itself is never touched by them.
String _ensureFlutterSolidartImport(String text, CompilationUnit unit) {
  final directives = unit.directives.whereType<ImportDirective>().toList();
  final sourceUris = <String>[];
  final sourceDirectiveText = <String, String>{};
  for (final directive in directives) {
    final uri = directive.uri.stringValue;
    if (uri == null) continue;
    sourceUris.add(uri);
    sourceDirectiveText[uri] = directive.toSource();
  }
  final imports = computeOutputImports(
    sourceUris,
    addSolidart: true,
    referencesSolidAnnotations: true,
  );
  final importBlock = imports
      .map((uri) => sourceDirectiveText[uri] ?? "import '$uri';")
      .join('\n');
  if (directives.isEmpty) {
    return '$importBlock\n\n$text';
  }
  return text.substring(0, directives.first.offset) +
      importBlock +
      text.substring(directives.last.end);
}

/// Resolved-path fallback for a BARE `super.` formal parameter (issue #106
/// residual gap survey, GAP 3): [param]'s own AST carries no type
/// annotation, but on a fully-resolved [CompilationUnit],
/// `declaredFragment.element.type` still resolves to the forwarded
/// parameter's real type (verified empirically against `package:analyzer`
/// directly — the analyzer resolves a super-initializer parameter's type
/// from the superclass constructor's matching parameter even when nothing
/// is written at this position). Seeds [wantedTypes] the same way
/// [_seedWantedTypeRecursive] would if the source had spelled the type out.
///
/// No-ops when the unit isn't resolved (`declaredFragment` unpopulated) or
/// the resolved type isn't an [InterfaceType] (e.g. a dynamic/unresolved
/// forward) — the caller already has nothing to add in that case, same as
/// today's syntactic-only behavior.
///
/// Returns whether [param] was resolved at all (an [InterfaceType] was
/// found), regardless of whether the type text turned out to be a core-SDK
/// name or already in the registry — the caller (issue #108 fix review
/// finding 2) uses this to skip [_seedFromSyntacticSuperFormal] entirely
/// once this resolved path has already answered the question; running the
/// syntactic import-and-parse walk anyway on a fully-resolved unit is pure
/// waste.
bool _seedFromResolvedSuperFormal(
  SuperFormalParameter param,
  Set<String> wantedTypes,
  Map<String, Set<String>> classRegistry,
) {
  final type = param.declaredFragment?.element.type;
  if (type is! InterfaceType) return false;
  final typeText = type.element.name;
  if (typeText == null) return false;
  if (_coreSdkTypeNames.contains(typeText)) return true;
  if (classRegistry.containsKey(typeText)) return true;
  wantedTypes.add(typeText);
  return true;
}

/// Depth bound for [_seedFromSyntacticSuperFormal]'s chain recursion (issue
/// #108 fix review addendum finding B): a bare super-formal parameter can
/// itself forward through another bare super-formal parameter one or more
/// superclasses further up (`GrandChild(super.x) extends Child(super.x)
/// extends Base(this.x)`). Five hops is generous for any real inheritance
/// chain while still bounding the walk — same rationale as any other
/// bounded search in this file, never expected to bite in practice.
const int _kMaxSuperFormalChainDepth = 5;

/// Syntactic counterpart to [_seedFromResolvedSuperFormal] for a bare
/// `super.x` in a file that never reaches a resolved unit — the PURE
/// CONSUMER shape issue #108 reports: a file with no `@Solid*` annotation
/// and no provider hint takes the no-annotation fast path's UNRESOLVED
/// probe, where `param.declaredFragment` is never populated.
///
/// Resolves [param]'s type from the AST alone: reads [subclass]'s own
/// `extends` clause for the superclass's simple name, locates that class's
/// declaration — checking [unit]'s own top-level declarations first (a
/// local declaration always shadows a same-name import, mirroring the
/// shadowing rule [_populateCrossFileTypes] itself applies to `wantedTypes`
/// — skipped entirely when the `extends` clause is itself import-prefixed,
/// since a prefixed reference can never resolve to a local declaration)
/// and otherwise walking [unit]'s imports — alias-aware (issue #108 fix
/// review finding 3): an unprefixed `extends Base` is skipped past any
/// `import ... as x;` directive (such an import can never bring an
/// unprefixed name into scope), and a prefixed `extends x.Base` considers
/// ONLY the import whose own prefix is `x`; same-package-only (finding 2:
/// a cross-package file can never host this package's `@SolidState`
/// classes — critically, this is what keeps `{super.key}` on an ordinary
/// widget from ever chasing `StatefulWidget`/`State` into
/// `package:flutter`); and never commits to the first import that merely
/// LOOKS like it could expose the name — scanning continues past a
/// resolvable import whose target file doesn't actually declare the class,
/// exactly like [_populateCrossFileTypes]'s own main walk does for a
/// same-named decoy.
///
/// Then finds the super-constructor [constructor]'s initializer list
/// targets (`super.named(...)` names a named constructor; no explicit
/// invocation at all means the implicit call to the unnamed constructor)
/// and matches [param] against that target's corresponding parameter:
/// positional by position among [constructor]'s OTHER positional `super.`
/// siblings (mirrors the language's own rule that only super-formal
/// parameters, in declaration order, populate the implicit super call —
/// Dart itself rejects mixing a positional `super.x` with an explicit
/// positional argument in the same invocation, so this position is never
/// ambiguous for code that compiles), named by matching name. When the
/// matched parameter is itself a `this.x` field formal with no type written
/// at that position either, falls back to the superclass's same-named
/// instance field's declared type. When the matched parameter is ITSELF a
/// bare `super.x` (the chain shape from finding B above), this function
/// recurses one level further up the inheritance chain — rooted at the
/// located superclass as the new subclass, the matched constructor as the
/// new constructor, and the matched parameter as the new target — up to
/// [_kMaxSuperFormalChainDepth] hops; beyond that bound it gives up the
/// chase and falls back to [_seedAllFromSuperclass] at the last class
/// reached, same as any other ambiguity below.
///
/// On any other ambiguity — the superclass declaration can't be located,
/// the targeted constructor can't be pinned down, or the matched parameter
/// resolves to no usable [NamedType] and isn't a further super-formal —
/// delegates to [_seedAllFromSuperclass], which seeds every candidate name
/// from the located superclass instead of guessing or skipping silently.
///
/// Returns the `(CompilationUnit, AssetId)` of whichever file the located
/// superclass (at whatever depth the resolution bottomed out on) is
/// declared in, but ONLY when that file differs from [unit]/[hostAssetId]
/// — i.e. exactly when the caller needs the one-hop extension
/// ([_populateCrossFileTypesOneHop]) to find the derived name's own
/// declaration, because [unit]'s own import walk (the one this function
/// runs to locate the superclass) never reaches that file directly.
/// Returns `null` when the superclass couldn't be located at all, or was
/// found locally in [unit] (no hop needed — [unit]'s own directives are
/// already covered by the caller's main walk).
Future<(CompilationUnit, AssetId)?> _seedFromSyntacticSuperFormal(
  SuperFormalParameter param,
  ClassDeclaration subclass,
  ConstructorDeclaration constructor,
  CompilationUnit unit,
  AssetId hostAssetId,
  BuildStep step,
  Set<String> wantedTypes,
  Map<String, Set<String>> classRegistry, {
  int depth = 0,
}) async {
  if (depth > _kMaxSuperFormalChainDepth) return null;

  final superclass = subclass.extendsClause?.superclass;
  final superclassName = superclass?.name.lexeme;
  if (superclassName == null) return null;
  final requiredPrefix = superclass?.importPrefix?.name.lexeme;

  ClassDeclaration? superDecl;
  CompilationUnit? superDeclUnit;
  AssetId? superDeclAssetId;

  // A prefixed reference (`extends x.Base`) can never resolve to a local,
  // unprefixed top-level declaration — only the import-walk branch below
  // can satisfy it.
  if (requiredPrefix == null) {
    superDecl = unit.declarations
        .whereType<ClassDeclaration>()
        .where((d) => d.name.lexeme == superclassName)
        .firstOrNull;
  }

  if (superDecl == null) {
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final uri = directive.uri.stringValue;
      if (uri == null || uri.startsWith('dart:')) continue;
      // Alias-aware filtering (finding 3): an unprefixed name can only come
      // from an unprefixed import; a prefixed name only from the import
      // carrying that exact prefix. `_importExposesName` alone can't tell
      // these apart — it only inspects show/hide combinators, never the
      // `as` clause — so a prefixed decoy import would otherwise pass its
      // check for an unprefixed name it can never actually expose.
      final directivePrefix = directive.prefix?.name;
      if (requiredPrefix == null) {
        if (directivePrefix != null) continue;
      } else if (directivePrefix != requiredPrefix) {
        continue;
      }
      if (!_importExposesName(directive, superclassName)) continue;
      final assetId = _resolveImportToSourceAsset(uri, hostAssetId);
      if (assetId == null || !assetId.path.endsWith('.dart')) continue;
      // Same-package guard (finding 2): this package's `@SolidState`
      // classes can never live in a cross-package file, so cross-package
      // imports (`package:flutter/...`, any other dependency) are skipped
      // before the read/parse cost is paid at all.
      if (assetId.package != step.inputId.package) continue;
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
      // Keep scanning past a resolvable import whose target file simply
      // doesn't declare the class — same "don't commit to the first URI
      // that merely looks promising" discipline the main registry walk
      // applies to a same-named-but-unannotated decoy (finding 3).
      final match = imported.declarations
          .whereType<ClassDeclaration>()
          .where((d) => d.name.lexeme == superclassName)
          .firstOrNull;
      if (match == null) continue;
      superDecl = match;
      superDeclUnit = imported;
      superDeclAssetId = assetId;
      break;
    }
  }
  if (superDecl == null) return null;

  // The file hosting whatever candidate this call ultimately seeds from —
  // the located superclass's own file when it came from an import, else
  // `null` (found in `unit` itself, no one-hop needed).
  (CompilationUnit, AssetId)? hopInfo() =>
      superDeclUnit != null ? (superDeclUnit, superDeclAssetId!) : null;

  // The target super-constructor's name: `null` for the unnamed
  // constructor, which is also the correct default when [constructor] has
  // no explicit `super(...)`/`super.named(...)` invocation at all — Dart's
  // implicit super call always targets the unnamed constructor.
  String? targetName;
  var sawSuperInvocation = false;
  for (final initializer in constructor.initializers) {
    if (initializer is SuperConstructorInvocation) {
      sawSuperInvocation = true;
      targetName = initializer.constructorName?.name;
    }
  }
  final targetCtor = sawSuperInvocation
      ? superDecl.members
            .whereType<ConstructorDeclaration>()
            .where((c) => c.name?.lexeme == targetName)
            .firstOrNull
      : superDecl.members
            .whereType<ConstructorDeclaration>()
            .where((c) => c.name == null)
            .firstOrNull;
  if (targetCtor == null) {
    _seedAllFromSuperclass(superDecl, wantedTypes, classRegistry);
    return hopInfo();
  }

  FormalParameter? matchedParam;
  if (param.isNamed) {
    matchedParam = targetCtor.parameters.parameters
        .where((p) => p.isNamed && p.name?.lexeme == param.name.lexeme)
        .firstOrNull;
  } else {
    final positionalSuperSiblings = constructor.parameters.parameters.where((
      p,
    ) {
      final inner = p is DefaultFormalParameter ? p.parameter : p;
      return inner is SuperFormalParameter && inner.isPositional;
    }).toList();
    final index = positionalSuperSiblings.indexWhere((p) {
      final inner = p is DefaultFormalParameter ? p.parameter : p;
      return identical(inner, param);
    });
    final targetPositional = targetCtor.parameters.parameters
        .where((p) => p.isPositional)
        .toList();
    if (index >= 0 && index < targetPositional.length) {
      matchedParam = targetPositional[index];
    }
  }
  if (matchedParam == null) {
    _seedAllFromSuperclass(superDecl, wantedTypes, classRegistry);
    return hopInfo();
  }

  final matchedInner = matchedParam is DefaultFormalParameter
      ? matchedParam.parameter
      : matchedParam;

  // Chain case (addendum finding B): the matched parameter is itself a bare
  // super-formal, forwarding one level further up the inheritance chain
  // (`GrandChild(super.x) extends Child(super.x) extends Base(this.x)`).
  // Recurse rooted at the located superclass, bounded by
  // [_kMaxSuperFormalChainDepth]; beyond the bound, fall back to
  // over-seeding at the last class actually reached rather than silently
  // dropping the chain.
  if (matchedInner is SuperFormalParameter) {
    if (depth + 1 > _kMaxSuperFormalChainDepth) {
      _seedAllFromSuperclass(superDecl, wantedTypes, classRegistry);
      return hopInfo();
    }
    return _seedFromSyntacticSuperFormal(
      matchedInner,
      superDecl,
      targetCtor,
      superDeclUnit ?? unit,
      superDeclAssetId ?? hostAssetId,
      step,
      wantedTypes,
      classRegistry,
      depth: depth + 1,
    );
  }

  TypeAnnotation? matchedType;
  if (matchedInner is SimpleFormalParameter) {
    matchedType = matchedInner.type;
  } else if (matchedInner is FieldFormalParameter) {
    matchedType =
        matchedInner.type ??
        _fieldTypeInClass(superDecl, matchedInner.name.lexeme);
  }
  if (matchedType is! NamedType) {
    _seedAllFromSuperclass(superDecl, wantedTypes, classRegistry);
    return hopInfo();
  }
  // Generic superclass type-parameter mapping (issue #108 fix review
  // addendum finding 2): `matchedType`'s name may itself be one of
  // [superDecl]'s own declared type parameters (`class Base<T> {
  // Base(this.repo); final T repo; }`) rather than a real class name — a
  // bare type-parameter reference is a perfectly ordinary [NamedType], so
  // it passes the `matchedType is! NamedType` ambiguity gate above
  // undetected, and seeding it verbatim would add the literal placeholder
  // name (`"T"`) to `wantedTypes`, matching no class anywhere and silently
  // dropping the real dependency. Map it BY INDEX to the type argument
  // [subclass] itself supplies in its `extends Base<AuthRepository>`
  // clause instead, then seed THAT (recursing through
  // [_seedWantedTypeRecursive] handles further nesting, e.g. `extends
  // Base<List<AuthRepository>>`). Falls back to [_seedAllFromSuperclass]
  // — never a bare type-parameter name — when the extends clause supplies
  // no type arguments at all, or fewer than [superDecl] declares.
  final matchedTypeName = matchedType.name.lexeme;
  final declaredTypeParams = superDecl.typeParameters?.typeParameters;
  final typeParamIndex = declaredTypeParams?.indexWhere(
    (p) => p.name.lexeme == matchedTypeName,
  );
  if (typeParamIndex != null && typeParamIndex != -1) {
    final typeArgs = superclass?.typeArguments?.arguments;
    final resolvedArg = typeArgs != null && typeParamIndex < typeArgs.length
        ? typeArgs[typeParamIndex]
        : null;
    if (resolvedArg is NamedType) {
      _seedWantedTypeRecursive(resolvedArg, wantedTypes, classRegistry);
    } else {
      _seedAllFromSuperclass(superDecl, wantedTypes, classRegistry);
    }
    return hopInfo();
  }
  _seedWantedTypeRecursive(matchedType, wantedTypes, classRegistry);
  return hopInfo();
}

/// Ambiguity fallback for [_seedFromSyntacticSuperFormal]: seeds every
/// candidate type name from [superDecl] — every instance field's declared
/// type, plus every constructor parameter's declared type across every
/// constructor — rather than guessing a single (possibly wrong) match or
/// skipping silently. Mirrors the annotation-blind, over-seeding-is-harmless
/// contract the rest of [_populateCrossFileTypes]'s seeding already relies
/// on: a candidate name that matches no `@SolidState`-bearing class is
/// simply never consumed downstream. Widens the pre-existing same-simple-
/// name registry-collision surface a little further (§4.9's residual risk
/// of the name-based registry design): every field/param type name on
/// [superDecl] enters `wantedTypes`, including names that would otherwise
/// never have been proposed as candidates for this file at all.
void _seedAllFromSuperclass(
  ClassDeclaration superDecl,
  Set<String> wantedTypes,
  Map<String, Set<String>> classRegistry,
) {
  for (final member in superDecl.members) {
    if (member is FieldDeclaration) {
      final type = member.fields.type;
      if (type is NamedType) {
        _seedWantedTypeRecursive(type, wantedTypes, classRegistry);
      }
    } else if (member is ConstructorDeclaration) {
      for (final param in member.parameters.parameters) {
        final inner = param is DefaultFormalParameter ? param.parameter : param;
        TypeAnnotation? type;
        if (inner is SimpleFormalParameter) {
          type = inner.type;
        } else if (inner is FieldFormalParameter) {
          type = inner.type;
        }
        if (type is NamedType) {
          _seedWantedTypeRecursive(type, wantedTypes, classRegistry);
        }
      }
    }
  }
}

/// Returns the declared [TypeAnnotation] of [classDecl]'s instance field
/// named [fieldName], or `null` if no such field exists. Fallback for a
/// `this.x` field-formal constructor parameter written with no type of its
/// own — the common shape (`Foo(this.x); final AuthRepository x;`), where
/// the type lives on the field declaration, not the parameter.
TypeAnnotation? _fieldTypeInClass(
  ClassDeclaration classDecl,
  String fieldName,
) {
  for (final member in classDecl.members) {
    if (member is! FieldDeclaration) continue;
    for (final variable in member.fields.variables) {
      if (variable.name.lexeme == fieldName) return member.fields.type;
    }
  }
  return null;
}

/// Translates a `source/<rel>` AssetId to its `lib/<rel>` sibling. The
/// inverse of [_resolveImportToSourceAsset]'s `lib/` → `source/` redirect.
/// Passes non-`source/` AssetIds through unchanged.
AssetId _sourceToLibAsset(AssetId asset) => asset.path.startsWith('source/')
    ? AssetId(asset.package, 'lib/${asset.path.substring('source/'.length)}')
    : asset;

/// Returns the relative URI from the lib-path of [fromSource] to the
/// lib-path of [toSource]. Both AssetIds must be same-package; both paths are
/// expected under `source/`. The result is the relative form (`'../foo.dart'`
/// or `'foo.dart'`) suitable for emission inside `lib/`, satisfying the
/// project-wide `prefer_relative_imports` convention.
String _relativeLibImportFrom(AssetId fromSource, AssetId toSource) {
  final fromLib = _sourceToLibAsset(fromSource).path;
  final toLib = _sourceToLibAsset(toSource).path;
  // Drop the consumer's own filename — relative path is computed from the
  // containing directory, not from the file itself.
  final fromDirSegs = fromLib.split('/')..removeLast();
  final toSegs = toLib.split('/');
  var common = 0;
  while (common < fromDirSegs.length &&
      common < toSegs.length - 1 &&
      fromDirSegs[common] == toSegs[common]) {
    common++;
  }
  final ups = List<String>.filled(fromDirSegs.length - common, '..');
  final downs = toSegs.sublist(common);
  final combined = [...ups, ...downs].join('/');
  return combined.isEmpty ? toSegs.last : combined;
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
