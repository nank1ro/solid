# Solid Framework

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://github.com/nank1ro/solid/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/nank1ro/solid)](https://gitHub.com/nank1ro/solid/stargazers/)
[![GitHub issues](https://img.shields.io/github/issues/nank1ro/solid)](https://gitHub.com/nank1ro/solid/issues/)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/nank1ro/solid.svg)](https://gitHub.com/nank1ro/solid/pull/)
[![solid_generator Pub Version (including pre-releases)](https://img.shields.io/pub/v/solid_generator?include_prereleases&label=solid_generator)](https://pub.dev/packages/solid_generator)
[![solid_annotations Pub Version (including pre-releases)](https://img.shields.io/pub/v/solid_annotations?include_prereleases&label=solid_annotations)](https://pub.dev/packages/solid_annotations)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/nank1ro)](https://github.com/sponsors/nank1ro)

<a href="https://www.buymeacoffee.com/nank1ro" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

Congrats on your interest in **Solid**! Let's make Flutter development even more enjoyable.

Solid is a tiny framework built on top of Flutter that makes building apps easier and more enjoyable.
The benefits of using Solid include:
1. **Don't write boilerplate**: Solid generates boilerplate code for you, so you can focus on building your app. Inspired by SwiftUI.
2. **No state management/dependency injection manual work**: Solid has built-in state management and dependency injection. Just annotate your variables and Solid takes care of the rest.
3. **Fine-grained reactivity**: Solid's reactivity system is inspired by SolidJS, allowing for efficient and fine-grained updates to your UI. Only the parts of the UI that depend on changed state are updated, leading to better performance. And the best is that you don't have to think about it, Solid does it for you automatically.

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

[![Demo of Solid fine-grained reactivity](./docs/src/assets/solid_demo.gif)](../../assets/solid_demo.gif)

As you can see, the `DateTime.now()` text does not update when the counter changes, only the `Counter is X` text updates. This is because Solid tracks which parts of the UI depend on which state, and only updates those parts when the state changes, without any manual work from you.

If this sounds interesting, check out the [Getting Started Guide](https://solid.mariuti.com/guides/getting-started) to learn how to set up Solid in your Flutter project!

## License

The Solid framework is open-source software licensed under the [MIT License](./LICENSE).

## Sponsorship

If you find Solid useful and would like to support its development, consider sponsoring the project on [GitHub Sponsors](https://github.com/sponsors/nank1ro/).
I love building open-source software and your support helps me dedicate more time to improving Solid and adding new features.
