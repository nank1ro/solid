import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// `true` iff [uri] is a `package:<packageName>/...` URI.
///
/// Shared by the Element-based matchers in `annotation_reader`,
/// `class_kind`, `target_validator`, and `provider_dispose_rewriter`:
/// each pairs an Element's class name with its declaring library's
/// package origin to identify well-known types from `solid_annotations`,
/// `flutter_solidart`, `flutter`, and `provider`.
bool isFromPackage(Uri uri, String packageName) =>
    uri.scheme == 'package' && uri.pathSegments.first == packageName;

/// `true` iff [supertypes] contains an interface element named [className],
/// optionally constrained to a `package:<packageName>/...` declaring
/// library via [isFromPackage].
///
/// The class's own element is NOT included by the analyzer's
/// `InterfaceElement.allSupertypes`; callers that need to match the type
/// itself check `type.element.name == className` separately and use this
/// helper only for the supertype chain.
bool supertypeChainContains(
  List<InterfaceType> supertypes,
  String className, {
  String? packageName,
}) {
  for (final supertype in supertypes) {
    final element = supertype.element;
    if (element.name != className) continue;
    if (packageName == null) return true;
    if (isFromPackage(element.library.uri, packageName)) return true;
  }
  return false;
}

/// Lexemes of the well-known `flutter_solidart` reactive-primitive types
/// rejected on an `@SolidEnvironment` field / matched as a foreign-signal
/// receiver. Most (`Signal`, `Computed`, `Resource`) extend `SignalBase<T>`;
/// `Effect` does NOT (it `implements ReactionInterface`) but is included
/// here as the same kind of generator-adjacent primitive an env field
/// shouldn't hold directly. Matched against a type-annotation lexeme as the
/// unresolved-AST fallback in `target_validator._isSignalBaseTyped` and
/// `value_rewriter._isSolidartSignalReceiver`; the Element-based primary
/// path — [isSolidartSignalType], which genuinely checks the `SignalBase`
/// supertype chain — does not need this exception and correctly excludes
/// `Effect`. Excludes `SignalBuilder` / `SolidartConfig` (non-reactive
/// solidart names).
const Set<String> signalBaseTypeNames = {
  'Signal',
  'Computed',
  'Effect',
  'Resource',
};

/// `true` iff [type] is `SignalBase<T>` or a subtype of it.
///
/// `SignalBase` and its subtypes are declared in `package:solidart`;
/// `package:flutter_solidart` re-exports them. The declaring library — not
/// the importing one — is what an Element reports, so both package names are
/// accepted.
bool isSolidartSignalType(InterfaceType type) {
  if (_isSignalBaseElement(type.element)) return true;
  for (final supertype in type.allSupertypes) {
    if (_isSignalBaseElement(supertype.element)) return true;
  }
  return false;
}

bool _isSignalBaseElement(InterfaceElement element) =>
    element.name == 'SignalBase' &&
    (isFromPackage(element.library.uri, 'solidart') ||
        isFromPackage(element.library.uri, 'flutter_solidart'));
