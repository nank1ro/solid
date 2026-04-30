import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/annotation_reader.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Validates every `@SolidState` annotation in [unit] against the SPEC
/// Section 3.1 valid-target list. Throws [ValidationError] on the first
/// invalid placement; returns silently when every annotation targets a
/// valid declaration (instance field or instance getter).
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

/// Validates every `@SolidEffect` annotation in [unit] against the SPEC
/// Section 3.4 valid-target list. Throws [ValidationError] on the first
/// invalid placement; returns silently when every annotation targets a
/// valid declaration (instance method with no parameters and `void` return).
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

// --- @SolidState target validator (SPEC §3.1) ---

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
/// silently — they are the canonical SPEC 3.1 valid target.
void _validateField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidStateName, field.metadata) == null) return;
  final varList = field.fields;
  final fieldName = varList.variables.first.name.lexeme;
  final location = '$className.$fieldName';
  // Order matters: `static const` reports as "const field" — the const-ness
  // is the dominant violation per the M1-14 TODO parenthetical guidance.
  if (varList.isConst) _reject('const field', location);
  if (varList.isFinal) _reject('final field', location);
  if (field.isStatic) _reject('static field', location);
}

/// Rejects `@SolidState` on a setter, static getter, or non-accessor method.
/// Instance getters fall through — they are valid SPEC 3.1 targets and M2
/// will emit `Computed`.
void _validateMethod(MethodDeclaration method, String className) {
  if (findAnnotationByName(solidStateName, method.metadata) == null) return;
  final location = '$className.${method.name.lexeme}';
  if (method.isSetter) _reject('setter', location);
  if (method.isGetter && method.isStatic) _reject('static getter', location);
  if (!method.isGetter && !method.isSetter) _reject('method', location);
  // Instance getter — valid SPEC 3.1 target; M2 emits Computed.
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

// --- @SolidEffect target validator (SPEC §3.4) ---

/// Throws a [ValidationError] for `@SolidEffect` on a [kind] of declaration.
/// Picks the indefinite article from `kind`'s first letter so the message
/// reads naturally ("a getter" vs "an abstract method").
Never _rejectEffect(String kind, String location) {
  final article = 'aeiouAEIOU'.contains(kind[0]) ? 'an' : 'a';
  throw ValidationError(
    '@SolidEffect cannot be applied to $article $kind',
    location,
    'INVALID_EFFECT_TARGET_${_kindCode(kind)}',
  );
}

/// Rejects `@SolidEffect` on any field. The SPEC §3.4 bullet does not
/// subdivide field kinds, so static and instance fields share the single
/// `'field'` label.
void _validateEffectField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidEffectName, field.metadata) == null) return;
  final fieldName = field.fields.variables.first.name.lexeme;
  _rejectEffect('field', '$className.$fieldName');
}

/// Rejects `@SolidEffect` on a getter, setter, static method, abstract or
/// external method, parameterized method, or non-void method. Instance methods
/// declared with `void` return and zero parameters fall through silently —
/// they are the canonical SPEC §3.4 valid target.
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

/// Rejects `@SolidEffect` on top-level declarations: variables, getters,
/// setters, and functions. The SPEC §3.4 bullet calls out "top-level function"
/// — top-level getters/setters/variables share the same fail-fast path with
/// per-kind labels.
void _validateEffectTopLevel(CompilationUnitMember decl) {
  if (decl is TopLevelVariableDeclaration &&
      findAnnotationByName(solidEffectName, decl.metadata) != null) {
    _rejectEffect(
      'top-level variable',
      decl.variables.variables.first.name.lexeme,
    );
  }
  if (decl is FunctionDeclaration &&
      findAnnotationByName(solidEffectName, decl.metadata) != null) {
    final name = decl.name.lexeme;
    if (decl.isGetter) _rejectEffect('top-level getter', name);
    if (decl.isSetter) _rejectEffect('top-level setter', name);
    _rejectEffect('top-level function', name);
  }
}

// --- @SolidQuery target validator (SPEC §3.5) ---

/// Validates every `@SolidQuery` annotation in [unit] against the SPEC
/// Section 3.5 valid-target list. Throws [ValidationError] on the first
/// invalid placement; returns silently when every annotation targets a
/// valid declaration (instance method with no parameters and a `Future<T>`
/// return type with `async` body, or a `Stream<T>` return type with either
/// a synchronous body or an `async*` block body).
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
/// Picks the indefinite article from `kind`'s first letter so the message
/// reads naturally ("a getter" vs "an abstract method").
Never _rejectQuery(String kind, String location) {
  final article = 'aeiouAEIOU'.contains(kind[0]) ? 'an' : 'a';
  throw ValidationError(
    '@SolidQuery cannot be applied to $article $kind',
    location,
    'INVALID_QUERY_TARGET_${_kindCode(kind)}',
  );
}

/// Rejects `@SolidQuery` on any field. The SPEC §3.5 bullet does not
/// subdivide field kinds, so static and instance fields share the single
/// `'field'` label.
void _validateQueryField(FieldDeclaration field, String className) {
  if (findAnnotationByName(solidQueryName, field.metadata) == null) return;
  final fieldName = field.fields.variables.first.name.lexeme;
  _rejectQuery('field', '$className.$fieldName');
}

/// Rejects `@SolidQuery` on a getter, setter, static method, abstract or
/// external method, parameterized method, non-Future/Stream-returning method,
/// or a `Future<T>`-returning method whose body is not `async`. Instance
/// methods declared with the `Future<T> … async` or `Stream<T> …` /
/// `Stream<T> … async*` shapes and zero parameters fall through silently —
/// they are the canonical SPEC §3.5 valid targets.
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
  // SPEC §3.5: return type must be Future<T> or Stream<T>.
  final returnType = method.returnType;
  final returnName = returnType is NamedType ? returnType.name.lexeme : null;
  if (returnName != futureLexeme && returnName != streamLexeme) {
    _rejectQuery('non-Future/Stream method', location);
  }
  // SPEC §3.5: Future<T> requires `async`. A null body keyword (expression
  // body without `async`, e.g. `=> Future.value(0)`) is intentionally
  // caught here — `?.lexeme` returns `null`, and `null != 'async'` is
  // `true`. Mirrors `annotation_reader.dart`'s `?.lexeme ?? ''` pattern.
  // Stream-form mismatches are out of scope (Stream has two valid shapes:
  // sync-return or async*); they are exercised positively in M5-02.
  final bodyKeyword = method.body.keyword?.lexeme;
  if (returnName == futureLexeme && bodyKeyword != 'async') {
    _rejectQuery(
      'method whose body keyword does not match the return type',
      location,
    );
  }
}

/// Rejects `@SolidQuery` on top-level declarations: variables, getters,
/// setters, and functions. The SPEC §3.5 bullet calls out "top-level function"
/// — top-level getters/setters/variables share the same fail-fast path with
/// per-kind labels.
void _validateQueryTopLevel(CompilationUnitMember decl) {
  if (decl is TopLevelVariableDeclaration &&
      findAnnotationByName(solidQueryName, decl.metadata) != null) {
    _rejectQuery(
      'top-level variable',
      decl.variables.variables.first.name.lexeme,
    );
  }
  if (decl is FunctionDeclaration &&
      findAnnotationByName(solidQueryName, decl.metadata) != null) {
    final name = decl.name.lexeme;
    if (decl.isGetter) _rejectQuery('top-level getter', name);
    if (decl.isSetter) _rejectQuery('top-level setter', name);
    _rejectQuery('top-level function', name);
  }
}
