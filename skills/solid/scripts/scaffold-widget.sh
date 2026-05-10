#!/usr/bin/env bash
# Scaffold a starter Solid widget under source/<snake_case>.dart.
# Usage: scaffold-widget.sh <PascalCaseName> [--state|--query|--env]
# Run from the package root. Refuses to overwrite an existing file.

set -eu

usage() {
  echo "usage: scaffold-widget.sh <PascalCaseName> [--state|--query|--env]" >&2
  exit 2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

name="$1"
kind="${2:---state}"

if [[ ! "$name" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
  echo "scaffold-widget.sh: name must be PascalCase (got '$name')" >&2
  exit 2
fi

case "$kind" in
  --state|--query|--env) ;;
  *) usage ;;
esac

if [[ ! -f pubspec.yaml ]]; then
  echo "scaffold-widget.sh: must be run from a package root (no pubspec.yaml here)" >&2
  exit 2
fi

mkdir -p source

# PascalCase -> snake_case (e.g. CounterPage -> counter_page)
snake="$(printf '%s' "$name" \
  | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g; s/([A-Z]+)([A-Z][a-z])/\1_\2/g' \
  | tr '[:upper:]' '[:lower:]')"
file="source/${snake}.dart"

if [[ -e "$file" ]]; then
  echo "scaffold-widget.sh: refusing to overwrite existing $file" >&2
  exit 1
fi

case "$kind" in
  --state)
    cat >"$file" <<EOF
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ${name} extends StatelessWidget {
  ${name}({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Counter is \$counter')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
EOF
    ;;
  --query)
    cat >"$file" <<EOF
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ${name} extends StatelessWidget {
  const ${name}({super.key});

  @SolidQuery()
  Future<String> fetchData() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: fetchData().when(
          ready: Text.new,
          loading: CircularProgressIndicator.new,
          error: (error, stackTrace) => Text('Error: \$error'),
        ),
      ),
    );
  }
}
EOF
    ;;
  --env)
    cat >"$file" <<EOF
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

// Replace \`Object\` with the type provided by an ancestor Provider<T> /
// .environment<T>(...) in the widget tree.
class ${name} extends StatelessWidget {
  ${name}({super.key});

  @SolidEnvironment()
  late Object value;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Value: \$value'));
  }
}
EOF
    ;;
esac

echo "Wrote $file"
