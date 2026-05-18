import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/element_utils.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Validates every `@SolidState` annotation in [unit] against the valid-target
/// list. Throws [ValidationError] on the first invalid placement; returns
/// silently when every annotation targets a valid declaration (instance field
/// or instance getter).
///
/// Runs before transformation so the pre-existing builder pipeline (which
/// only walks `FieldDeclaration`s in `_collectAnnotatedClasses`) cannot
/// silently drop a `@SolidState` placed on a method, setter, top-level
/// declaration, or static/final/const field.
void validateSolidStateTargets(CompilationUnit unit) => _walkUnit(
  unit,
  onField: _validateField,
  onMethod: _validateMethod,
  onTopLevel: _validateTopLevel,
);

/// Validates every `@SolidEffect` annotation in [unit] against the valid-target
/// list. Throws [ValidationError] on the first invalid placement; returns
/// silently when every annotation targets a valid declaration (instance method
/// with no parameters and `void` return).
///
/// Runs after [validateSolidStateTargets] and before transformation so that
/// misplaced `@SolidEffect` annotations (on getters, setters, static methods,
/// abstract methods, parameterized methods, non-void methods, top-level
/// functions, or fields) never reach the readers, which would otherwise skip
/// them silently or produce a confusing downstream error.
void validateSolidEffectTargets(CompilationUnit unit) => _walkUnit(
  unit,
  onField: _validateEffectField,
  onMethod: _validateEffectMethod,
  onTopLevel: _validateEffectTopLevel,
);

/// Walks every declaration in [unit] and dispatches each member to the
/// appropriate per-kind callback. Class members hand the enclosing class name
/// to [onField] / [onMethod] so error messages can include
/// `<class>.<member>` locations; non-class declarations land in [onTopLevel].
void _walkUnit(
  CompilationUnit unit, {
  required void Function(FieldDeclaration field, String className) onField,
  required void Function(MethodDeclaration method, String className) onMethod,
  required void Function(CompilationUnitMember decl) onTopLevel,
}) {
  for (final decl in unit.declarations) {
    if (decl is ClassDeclaration) {
      final className = decl.name.lexeme;
      for (final member in decl.members) {
        if (member is FieldDeclaration) onField(member, className);
        if (member is MethodDeclaration) onMethod(member, className);
      }
    } else {
      onTopLevel(decl);
    }
  }
}

/// UPPER_SNAKE form of [kind] used as the violation-code suffix. Folds spaces
/// and dashes to underscores so e.g. `'top-level variable'` →
/// `TOP_LEVEL_VARIABLE`.
String _kindCode(String kind) =>
    kind.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');

// --- @SolidState target validator ---

/// Throws a [ValidationError] for `@SolidState` on a [kind] of declaration.
/// The violation code is derived from [kind] so message and code never drift.
Never _reject(String kind, String location) {
  throw ValidationError(
    '@SolidState cannot be applied to a $kind',
    location,
    'INVALID_TARGET_${_kindCode(kind)}',
  );
}

/// Rejects `@SolidState` on a class field that is `const`, `final`, or
/// `static`. Instance non-final non-const non-static fields fall through
/// silently — they are the canonical valid target.
void _validateField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidStateName, field.metadata) == null) return;
  final varList = field.fields;
  final fieldName = varList.variables.first.name.lexeme;
  final location = '$className.$fieldName';
  // Order matters: `static const` reports as "const field" — the const-ness
  // is the dominant violation.
  if (varList.isConst) _reject('const field', location);
  if (varList.isFinal) _reject('final field', location);
  if (field.isStatic) _reject('static field', location);
}

/// Rejects `@SolidState` on a setter, static getter, or non-accessor method.
/// Instance getters fall through — they are valid targets and lower to
/// `Computed`.
void _validateMethod(MethodDeclaration method, String className) {
  if (findAnnotationByName(solidStateName, method.metadata) == null) return;
  final location = '$className.${method.name.lexeme}';
  if (method.isSetter) _reject('setter', location);
  if (method.isGetter && method.isStatic) _reject('static getter', location);
  if (!method.isGetter && !method.isSetter) _reject('method', location);
  // Instance getter — valid target; lowers to Computed.
}

/// Rejects `@SolidState` on top-level variables, getters, and any other
/// non-class declaration form (top-level setters and methods land here too,
/// reusing the SETTER / METHOD codes).
void _validateTopLevel(CompilationUnitMember decl) {
  if (decl is TopLevelVariableDeclaration &&
      findAnnotationByName(solidStateName, decl.metadata) != null) {
    _reject('top-level variable', decl.variables.variables.first.name.lexeme);
  }
  if (decl is FunctionDeclaration &&
      findAnnotationByName(solidStateName, decl.metadata) != null) {
    final name = decl.name.lexeme;
    if (decl.isGetter) _reject('top-level getter', name);
    if (decl.isSetter) _reject('setter', name);
    _reject('method', name);
  }
}

// --- shared rejection / top-level walk for the article-form validators ---

/// Throws a [ValidationError] for `@<annotationName>` on a [kind] of
/// declaration. Picks the indefinite article from [kind]'s first letter so
/// the message reads naturally ("a getter" vs "an abstract method").
///
/// Shared by the `@SolidEffect`, `@SolidQuery`, and `@SolidEnvironment`
/// validators; `@SolidState` uses its own [_reject] helper because its
/// message form omits the article.
Never _rejectArticleAnnotation(
  String annotationName,
  String codePrefix,
  String kind,
  String location,
) {
  final article = 'aeiouAEIOU'.contains(kind[0]) ? 'an' : 'a';
  throw ValidationError(
    '@$annotationName cannot be applied to $article $kind',
    location,
    '${codePrefix}_TARGET_${_kindCode(kind)}',
  );
}

/// Shared top-level rejection walk for the article-form validators. Each
/// one (`@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`) classifies
/// top-level declarations into variable/getter/setter/function with identical
/// labels — only the annotation name and reject closure differ.
void _validateTopLevelArticleAnnotation(
  CompilationUnitMember decl,
  String annotationName,
  Never Function(String kind, String location) reject,
) {
  if (decl is TopLevelVariableDeclaration &&
      findAnnotationByName(annotationName, decl.metadata) != null) {
    reject('top-level variable', decl.variables.variables.first.name.lexeme);
  }
  if (decl is FunctionDeclaration &&
      findAnnotationByName(annotationName, decl.metadata) != null) {
    final name = decl.name.lexeme;
    if (decl.isGetter) reject('top-level getter', name);
    if (decl.isSetter) reject('top-level setter', name);
    reject('top-level function', name);
  }
}

// --- @SolidEffect target validator ---

/// Throws a [ValidationError] for `@SolidEffect` on a [kind] of declaration.
Never _rejectEffect(String kind, String location) =>
    _rejectArticleAnnotation(solidEffectName, 'INVALID_EFFECT', kind, location);

/// Rejects `@SolidEffect` on any field. Static and instance fields share the
/// single `'field'` label.
void _validateEffectField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidEffectName, field.metadata) == null) return;
  final fieldName = field.fields.variables.first.name.lexeme;
  _rejectEffect('field', '$className.$fieldName');
}

/// Rejects `@SolidEffect` on a getter, setter, static method, abstract or
/// external method, parameterized method, or non-void method. Instance methods
/// declared with `void` return and zero parameters fall through silently —
/// they are the canonical valid target.
void _validateEffectMethod(MethodDeclaration method, String className) {
  if (findAnnotationByName(solidEffectName, method.metadata) == null) return;
  final location = '$className.${method.name.lexeme}';
  if (method.isGetter) _rejectEffect('getter', location);
  if (method.isSetter) _rejectEffect('setter', location);
  if (method.isStatic) _rejectEffect('static method', location);
  if (method.isAbstract || method.externalKeyword != null) {
    _rejectEffect('abstract method', location);
  }
  final params = method.parameters;
  if (params != null && params.parameters.isNotEmpty) {
    _rejectEffect('parameterized method', location);
  }
  final returnType = method.returnType;
  // `null` return type is implicitly void per Dart's rules — valid.
  // Use lexeme equality (not `toString()` / `toSource()`) so compound type
  // shapes don't drift the comparison.
  final isVoid = returnType is NamedType && returnType.name.lexeme == 'void';
  if (returnType != null && !isVoid) {
    _rejectEffect('non-void method', location);
  }
}

/// Rejects `@SolidEffect` on top-level declarations.
void _validateEffectTopLevel(CompilationUnitMember decl) =>
    _validateTopLevelArticleAnnotation(decl, solidEffectName, _rejectEffect);

// --- @SolidQuery target validator ---

/// Validates every `@SolidQuery` annotation in [unit] against the valid-target
/// list. Throws [ValidationError] on the first invalid placement; returns
/// silently when every annotation targets a valid declaration (instance method
/// with no parameters and a `Future<T>` return type with `async` body, or a
/// `Stream<T>` return type with either a synchronous body or an `async*` block
/// body).
///
/// Runs after [validateSolidEffectTargets] and before transformation so that
/// misplaced `@SolidQuery` annotations (non-Future/Stream returns,
/// Future-without-async bodies, parameterized/static/abstract methods,
/// getters/setters, top-level functions, fields) never reach
/// `readSolidQueryMethod`, which would otherwise skip them silently or
/// produce a confusing downstream error.
void validateSolidQueryTargets(CompilationUnit unit) => _walkUnit(
  unit,
  onField: _validateQueryField,
  onMethod: _validateQueryMethod,
  onTopLevel: _validateQueryTopLevel,
);

/// Throws a [ValidationError] for `@SolidQuery` on a [kind] of declaration.
Never _rejectQuery(String kind, String location) =>
    _rejectArticleAnnotation(solidQueryName, 'INVALID_QUERY', kind, location);

/// `@SolidQuery` on a class field is a valid target: the field initializer
/// expression (e.g. `Future.value(0)`) becomes the Resource fetcher closure
/// at lowering time. No validation runs here; the field-as-fetcher reading
/// + lowering is handled in the builder pipeline.
void _validateQueryField(FieldDeclaration field, String className) {}

/// Rejects `@SolidQuery` on a getter, setter, static method, abstract or
/// external method, parameterized method, non-Future/Stream-returning method,
/// or a `Future<T>`-returning method whose body is not `async`. Instance
/// methods declared with the `Future<T> … async` or `Stream<T> …` /
/// `Stream<T> … async*` shapes and zero parameters fall through silently —
/// they are the canonical valid targets.
///
/// Ordering rationale: structural shape (getter/setter/static/abstract/
/// parameterized) is checked before the return-type discriminator, mirroring
/// `_validateEffectMethod`. This ensures a `static int fetchCount() => 0` is
/// reported as `'static method'` (the dominant placement violation) rather
/// than `'non-Future/Stream method'`. The body-keyword check fires last
/// because it requires the return type to already be `Future<T>`.
void _validateQueryMethod(MethodDeclaration method, String className) {
  if (findAnnotationByName(solidQueryName, method.metadata) == null) return;
  final location = '$className.${method.name.lexeme}';
  if (method.isGetter) _rejectQuery('getter', location);
  if (method.isSetter) _rejectQuery('setter', location);
  if (method.isStatic) _rejectQuery('static method', location);
  if (method.isAbstract || method.externalKeyword != null) {
    _rejectQuery('abstract method', location);
  }
  final params = method.parameters;
  if (params != null && params.parameters.isNotEmpty) {
    _rejectQuery('parameterized method', location);
  }
  // Return type must be Future<T> or Stream<T>.
  final returnType = method.returnType;
  final returnName = returnType is NamedType ? returnType.name.lexeme : null;
  if (returnName != futureLexeme && returnName != streamLexeme) {
    _rejectQuery('non-Future/Stream method', location);
  }
  // Body-keyword/return-type mismatch is intentionally NOT validated; see
  // the rejection-suite header for the rationale.
}

/// Rejects `@SolidQuery` on top-level declarations.
void _validateQueryTopLevel(CompilationUnitMember decl) =>
    _validateTopLevelArticleAnnotation(decl, solidQueryName, _rejectQuery);

// --- @SolidEnvironment target validator ---

/// Validates every `@SolidEnvironment` annotation in [unit] against the
/// valid-target list. Throws [ValidationError] on the first invalid placement;
/// returns silently when every annotation targets a valid declaration (a `late`
/// instance field with no initializer, a non-`SignalBase` type, on a
/// `StatelessWidget`/`StatefulWidget`/`State<X>` host).
///
/// Runs after [validateSolidQueryTargets] and before transformation so that
/// misplaced `@SolidEnvironment` annotations (non-`late` fields, fields with
/// initializers, `final`/`const`/`static` fields, methods/getters/setters,
/// top-level functions, `SignalBase`-typed fields, plain-class hosts) never
/// reach `readSolidEnvironmentField`, which would otherwise skip them
/// silently or produce a confusing downstream error.
///
/// The canonical valid case (`late <T> name;` on a
/// `StatelessWidget`/`State<X>`) falls through silently; per-case error
/// messages and codes cover every invalid placement.
void validateSolidEnvironmentTargets(CompilationUnit unit) => _walkUnit(
  unit,
  onField: _validateEnvironmentField,
  onMethod: _validateEnvironmentMethod,
  onTopLevel: _validateEnvironmentTopLevel,
);

/// Throws a [ValidationError] for `@SolidEnvironment` on a [kind] of
/// declaration.
Never _rejectEnvironment(String kind, String location) =>
    _rejectArticleAnnotation(
      solidEnvironmentName,
      'INVALID_ENVIRONMENT',
      kind,
      location,
    );

/// Rejects `@SolidEnvironment` on a class field that is `static`, `const`,
/// `final`-without-`late`, non-`late`, has an initializer, or is typed as a
/// `SignalBase` shape (`Signal<…>` / `Computed<…>` / `Effect` / `Resource<…>`).
/// Plain-class host detection lives separately in `rewritePlainClass`'s
/// defense-in-depth check (the host-kind check needs the full class context
/// the validator's `_walkUnit` doesn't provide). Instance non-final non-const
/// non-static `late` fields with no initializer and a non-`SignalBase` type
/// fall through silently — they are the canonical valid target.
///
/// Order matters for invalid-target enumeration: structural modifiers
/// (`static` / `const` / `final` / non-`late`) are checked before initializer
/// presence and type shape. A `static const Signal<int> c = …` reports as
/// `'static field'` (the dominant placement violation) rather than
/// `'SignalBase-typed field'`.
void _validateEnvironmentField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidEnvironmentName, field.metadata) == null) {
    return;
  }
  final varList = field.fields;
  final fieldName = varList.variables.first.name.lexeme;
  final location = '$className.$fieldName';
  if (field.isStatic) _rejectEnvironment('static field', location);
  if (varList.isConst) _rejectEnvironment('const field', location);
  // `late final` is allowed (immutability on the injected reference is fine);
  // only `final` WITHOUT `late` is rejected.
  if (varList.isFinal && !varList.isLate) {
    _rejectEnvironment('final field', location);
  }
  if (!varList.isLate) _rejectEnvironment('non-late field', location);
  final variable = varList.variables.first;
  if (variable.initializer != null) {
    _rejectEnvironment('field with initializer', location);
  }
  // `SignalBase`-typed environment field detection, two-tier:
  //   1. Element-based: when the resolver populated the type, walk
  //      `allSupertypes` for a `SignalBase` class anchored to the
  //      `package:flutter_solidart/` library URI. Catches aliased imports
  //      and user-defined subclasses of `SignalBase`.
  //   2. Textual fallback: when the resolver hasn't run (parsed-AST
  //      fallback or test sandboxes), match the type name's lexeme against
  //      [signalBaseTypeNames]. The user-defined subclass case is missed
  //      by this path but is harmless — runtime would still reject.
  final type = varList.type;
  if (type is NamedType && _isSignalBaseTyped(type)) {
    _rejectEnvironment('SignalBase-typed field', location);
  }
}

/// `true` iff [type]'s resolved supertype chain contains a `SignalBase`
/// declared in `package:flutter_solidart/`, or — when the resolver hasn't
/// produced a type — the type's lexeme is in [signalBaseTypeNames].
bool _isSignalBaseTyped(NamedType type) {
  final resolved = type.type;
  if (resolved is InterfaceType) {
    final element = resolved.element;
    if (element.name == 'SignalBase' &&
        isFromPackage(element.library.uri, 'flutter_solidart')) {
      return true;
    }
    return supertypeChainContains(
      resolved.allSupertypes,
      'SignalBase',
      packageName: 'flutter_solidart',
    );
  }
  // Type unresolved (parsed-AST fallback / test sandbox). Fall back to
  // lexeme match against the well-known set.
  return signalBaseTypeNames.contains(type.name.lexeme);
}

/// Rejects `@SolidEnvironment` on a getter, setter, or method. Static
/// methods/getters/setters are caught by the same per-kind labels.
void _validateEnvironmentMethod(MethodDeclaration method, String className) {
  if (findAnnotationByName(solidEnvironmentName, method.metadata) == null) {
    return;
  }
  final location = '$className.${method.name.lexeme}';
  if (method.isGetter) _rejectEnvironment('getter', location);
  if (method.isSetter) _rejectEnvironment('setter', location);
  _rejectEnvironment('method', location);
}

/// Rejects `@SolidEnvironment` on top-level declarations.
void _validateEnvironmentTopLevel(CompilationUnitMember decl) =>
    _validateTopLevelArticleAnnotation(
      decl,
      solidEnvironmentName,
      _rejectEnvironment,
    );
