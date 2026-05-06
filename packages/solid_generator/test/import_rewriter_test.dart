// Unit tests for `computeOutputImports`. M8-01 added the
// `referencesSolidAnnotations` parameter; the integration suite covers the
// builder-level scan that produces it.

import 'package:solid_generator/src/import_rewriter.dart';
import 'package:test/test.dart';

const String _solidAnnotationsUri =
    'package:solid_annotations/solid_annotations.dart';

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
        expect(result, [
          'package:flutter/material.dart',
          _solidAnnotationsUri,
        ]);
      },
    );

    test(
      'preserves non-solid_annotations URIs and appends flutter_solidart / '
      'provider per their flags',
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
        expect(result, [
          'dart:async',
          'package:flutter/material.dart',
          flutterSolidartUri,
          providerUri,
        ]);
      },
    );
  });
}
