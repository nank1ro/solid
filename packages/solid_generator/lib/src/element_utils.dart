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
