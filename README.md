# Flutter Solid Framework

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://github.com/nank1ro/solid/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/nank1ro/solid)](https://gitHub.com/nank1ro/solid/stargazers/)
[![GitHub issues](https://img.shields.io/github/issues/nank1ro/solid)](https://gitHub.com/nank1ro/solid/issues/)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/nank1ro/solid.svg)](https://gitHub.com/nank1ro/solid/pull/)
[![solid_generator Pub Version (including pre-releases)](https://img.shields.io/pub/v/solid_generator?include_prereleases&label=solid_generator)](https://pub.dev/packages/solid_generator)
[![solid_annotations Pub Version (including pre-releases)](https://img.shields.io/pub/v/solid_annotations?include_prereleases&label=solid_annotations)](https://pub.dev/packages/solid_annotations)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/nank1ro)](https://github.com/sponsors/nank1ro)

<a href="https://www.buymeacoffee.com/nank1ro" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

Congrats on your interest in **Flutter Solid**! Let's make Flutter development even more enjoyable.

Solid is a tiny framework built on top of Flutter that makes building apps easier and more enjoyable.
The benefits of using Solid include:
1. **Don't write boilerplate**: Solid generates boilerplate code for you, so you can focus on building your app. Inspired by SwiftUI.
2. **No state management/dependency injection manual work**: Solid has built-in state management and dependency injection. Just annotate your variables and Solid takes care of the rest.
3. **Fine-grained reactivity**: Solid's reactivity system is inspired by SolidJS, allowing for efficient and fine-grained updates to your UI. Only the parts of the UI that depend on changed state are updated, leading to better performance. And the best is that you don't have to think about it, Solid does it for you automatically.

## Installation

Add Solid's runtime deps to your Flutter app, then add the generator and `build_runner` as dev dependencies:

```bash
flutter pub add solid_annotations flutter_solidart provider
dart pub add --dev solid_generator build_runner
dart run build_runner build
```

See the [Getting Started Guide](https://solid.mariuti.com/guides/getting-started) for the full setup including recommended lints.

## Example

You write this code, without any boilerplate and manual state management:

```dart
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${DateTime.now()}'),
            Text('Counter is $counter'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

You get this result, with real fine-grained reactivity:

[![Demo of Solid fine-grained reactivity](https://raw.githubusercontent.com/nank1ro/solid/main/docs/src/assets/solid_demo.gif)](https://github.com/nank1ro/solid/blob/main/docs/src/assets/solid_demo.gif)

As you can see, the `DateTime.now()` text does not update when the counter changes, only the `Counter is X` text updates. This is because Solid tracks which parts of the UI depend on which state, and only updates those parts when the state changes, without any manual work from you.

If this sounds interesting, check out the [Getting Started Guide](https://solid.mariuti.com/guides/getting-started) to learn how to set up Solid in your Flutter project!

## Annotations

Solid ships four annotations:

- **`@SolidState`** — declares reactive state on a field, or a derived value on a getter. See [State](https://solid.mariuti.com/guides/state).
- **`@SolidEffect`** — runs a side effect whenever its tracked dependencies change. See [Effect](https://solid.mariuti.com/guides/effect).
- **`@SolidQuery`** — wraps an async or stream call as a reactive resource with `.when(...)` UI states and refresh control. See [Query](https://solid.mariuti.com/guides/query).
- **`@SolidEnvironment`** — injects a dependency from the nearest ancestor `Provider<T>` in the widget tree, SwiftUI `@Environment` style. See [Environment](https://solid.mariuti.com/guides/environment).

## AI assistants

Solid inverts a few Flutter conventions (most importantly, you write `source/` and `lib/` is generated), so AI tools need a heads-up to write idiomatic Solid.

**Quickest path — drop in `AGENTS.md`.** Copy [`skills/solid/assets/AGENTS.md`](./skills/solid/assets/AGENTS.md) to the root of your Flutter app. Most AI coding tools (Claude Code, Cursor, Codex, GitHub Copilot, Amp, …) auto-load `AGENTS.md` at session start. Tools that look for `CLAUDE.md` instead can symlink: `ln -s AGENTS.md CLAUDE.md`.

**Deeper guidance — install the full skill.** Solid also ships an agent skill at [`skills/solid/`](./skills/solid/) for [skills.sh](https://skills.sh)-compatible agents, with verify scripts and richer examples:

```bash
npx skills add nank1ro/solid
```

Or copy `skills/solid/SKILL.md` into your editor's skill location manually.

If your tool fetches documentation over HTTP (Cursor `@docs`, ChatGPT custom GPTs, claude.ai web search, …), point it at [`/llms-full.txt`](https://solid.mariuti.com/llms-full.txt) — the full docs as a single LLM-friendly file. A short index lives at [`/llms.txt`](https://solid.mariuti.com/llms.txt).

## License

The Solid framework is open-source software licensed under the [MIT License](./LICENSE).

## Sponsorship

If you find Solid useful and would like to support its development, consider sponsoring the project on [GitHub Sponsors](https://github.com/sponsors/nank1ro/).
I love building open-source software and your support helps me dedicate more time to improving Solid and adding new features.
