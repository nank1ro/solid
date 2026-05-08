// Unit tests for `computeOutputImports`. Covers the
// `referencesSolidAnnotations` parameter and the `dart:` → `package:` →
// relative alphabetical sort. The integration suite covers the
// builder-level scan that produces `referencesSolidAnnotations`.

import 'package:solid_generator/src/import_rewriter.dart';
import 'package:test/test.dart';

const String _solidAnnotationsUri =
    '${solidAnnotationsUriPrefix}solid_annotations.dart';

void main() {
  group('computeOutputImports', () {
    test('drops solid_annotations URIs when referencesSolidAnnotations is '
        'false', () {
      final result = computeOutputImports(
        const [
          'package:flutter/material.dart',
          _solidAnnotationsUri,
        ],
        addSolidart: false,
        referencesSolidAnnotations: false,
      );
      expect(result, ['package:flutter/material.dart']);
    });

    test(
      'keeps solid_annotations URI when referencesSolidAnnotations is true',
      () {
        final result = computeOutputImports(
          const [
            'package:flutter/material.dart',
            _solidAnnotationsUri,
          ],
          addSolidart: false,
          referencesSolidAnnotations: true,
        );
        // `flutter/...` < `solid_annotations/...` alphabetically.
        expect(result, [
          'package:flutter/material.dart',
          _solidAnnotationsUri,
        ]);
      },
    );

    test(
      'preserves non-solid_annotations URIs and sorts appended flutter_solidart'
      ' / provider into alpha position',
      () {
        final result = computeOutputImports(
          const [
            'dart:async',
            _solidAnnotationsUri,
            'package:flutter/material.dart',
          ],
          addSolidart: true,
          addProvider: true,
          referencesSolidAnnotations: false,
        );
        // solid_annotations dropped; the remaining four URIs come out in
        // group-then-alpha order, with the appended flutter_solidart /
        // provider sorted into position rather than appended at the tail.
        expect(result, [
          'dart:async',
          'package:flutter/material.dart',
          flutterSolidartUri,
          providerUri,
        ]);
      },
    );
  });

  group('computeOutputImports alphabetical sort (SPEC §9)', () {
    List<String> sortOnly(List<String> uris) => computeOutputImports(
      uris,
      addSolidart: false,
      referencesSolidAnnotations: false,
    );

    test('orders dart: before package: regardless of source order', () {
      expect(
        sortOnly(const ['package:foo/foo.dart', 'dart:async']),
        ['dart:async', 'package:foo/foo.dart'],
      );
    });

    test('orders package: alphabetically by full URI', () {
      expect(
        sortOnly(const [
          'package:provider/provider.dart',
          'package:flutter/material.dart',
          'package:flutter_solidart/flutter_solidart.dart',
        ]),
        [
          'package:flutter/material.dart',
          'package:flutter_solidart/flutter_solidart.dart',
          'package:provider/provider.dart',
        ],
      );
    });

    test(
      'sorts package:flutter/... before package:flutter_solidart/...',
      () {
        expect(
          sortOnly(const [
            'package:flutter_solidart/flutter_solidart.dart',
            'package:flutter/material.dart',
          ]),
          [
            'package:flutter/material.dart',
            'package:flutter_solidart/flutter_solidart.dart',
          ],
        );
      },
    );

    test('places relative imports after package: imports', () {
      expect(
        sortOnly(const [
          'src/local.dart',
          'package:foo/foo.dart',
          'dart:async',
        ]),
        ['dart:async', 'package:foo/foo.dart', 'src/local.dart'],
      );
    });

    test('appended flutter_solidart and provider land in alpha slot, not at '
        'the tail', () {
      final result = computeOutputImports(
        const ['package:zzz/zzz.dart'],
        addSolidart: true,
        addProvider: true,
        referencesSolidAnnotations: false,
      );
      expect(result, [
        flutterSolidartUri,
        providerUri,
        'package:zzz/zzz.dart',
      ]);
    });
  });
}
