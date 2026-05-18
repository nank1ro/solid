# Solid patterns

Canonical idioms, each with a complete `source/` snippet. All examples lifted from the user docs at <https://solid.mariuti.com>.

## 1. Counter with `@SolidState` field

Docs: <https://solid.mariuti.com/guides/state>. The simplest reactive primitive — a mutable field whose reads are tracked.

```dart title="source/counter.dart"
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Counter is $counter')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Only the `Text` rebuilds when `counter` changes — fine-grained reactivity, no `setState`.

## 2. Computed value via `@SolidState` getter

Docs: <https://solid.mariuti.com/guides/state>. A getter annotated with `@SolidState` is a derived value that re-evaluates when its dependencies change.

```dart title="source/computed_counter.dart"
class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @SolidState()
  int get doubleCounter => counter * 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Computed')),
      body: Center(
        child: Text('Counter: $counter, DoubleCounter: $doubleCounter'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## 3. `@SolidEffect` reacting to state

Docs: <https://solid.mariuti.com/guides/effect>. A `void` instance method that re-runs whenever its tracked reads change.

```dart title="source/effect_example.dart"
class EffectExample extends StatelessWidget {
  EffectExample({super.key});

  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('Counter changed: $counter');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Effect')),
      body: Center(child: Text('Counter: $counter')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## 4. `@SolidQuery` async fetch with `.when(...)`

Docs: <https://solid.mariuti.com/guides/query>. Annotate a parameterless method returning `Future<T>` (or `Stream<T>`). The call site returns a `Resource<T>` you render with `.when`.

```dart title="source/query_example.dart"
class QueryExample extends StatelessWidget {
  const QueryExample({super.key});

  @SolidQuery()
  Future<String> fetchData() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Query')),
      body: Center(
        child: fetchData().when(
          ready: Text.new,
          loading: CircularProgressIndicator.new,
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ),
    );
  }
}
```

`fetchData().isRefreshing` is `true` while a re-execution is in flight; `fetchData.refresh()` triggers a manual re-run.

## 5. `@SolidQuery` reacting to state, with `debounce`

Docs: <https://solid.mariuti.com/guides/query>. The query has no parameters — it reads `@SolidState` fields from its body and re-runs whenever they change. `debounce` waits N after the last change before re-executing.

```dart title="source/query_with_source_example.dart"
class QueryWithSourceExample extends StatelessWidget {
  QueryWithSourceExample({super.key});

  @SolidState()
  String? userId;

  @SolidQuery(debounce: Duration(seconds: 1))
  Future<String?> fetchData() async {
    if (userId == null) return null;
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'Fetched Data for $userId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithSource')),
      body: Center(
        child: fetchData().when(
          ready: (data) {
            if (data == null) return const Text('No user ID provided');
            return Text(data);
          },
          loading: CircularProgressIndicator.new,
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            userId = 'user_${DateTime.now().millisecondsSinceEpoch}',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

## 6. `@SolidEnvironment` reading an ancestor `Provider<T>`

Docs: <https://solid.mariuti.com/guides/environment>. A `late` field on a `StatelessWidget` (or `State<X>`) bound to the nearest ancestor `Provider<T>`.

```dart title="source/counter_display.dart"
class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Counter is ${counter.value}'));
  }
}

class Counter {
  @SolidState()
  int value = 0;
}
```

Provide it via the `.environment<T>()` extension or a `Provider<T>`:

```dart title="source/main.dart"
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CounterDisplay().environment((_) => Counter()),
    );
  }
}
```

Or with `package:provider`:

```dart
import 'package:provider/provider.dart';

home: Provider(create: (_) => Counter(), child: CounterDisplay()),
```

For multiple providers, chain `.environment(...)` calls or use `MultiProvider`:

```dart
HomePage()
  .environment((_) => Counter())
  .environment((_) => Logger())
```

Reads of `@SolidState` members on the injected instance stay reactive — only the dependent UI rebuilds.

**Order matters when one provider's `create` reads another, and `.environment(...)` reads inverted.** `.environment(X)` wraps the receiver in `Provider<X>(child: receiver)`, so the LAST call in the chain is the OUTERMOST (top of the tree) — the chain reads bottom-up. `MultiProvider`'s `providers:` list is the natural top-down convention: list[0] is the outermost, list[last] is the innermost (just above `child:`), matching the equivalent nested `Provider(child: Provider(child: …))` form line-for-line.

For a Provider's `create` callback to find a dependency via `ctx.read<T>()`, the dependency must be ABOVE it. That means in a `.environment(...)` chain, dependencies go LAST; in a `MultiProvider` list, dependencies go FIRST. Get either backwards and the consumer's `create` throws `ProviderNotFoundException`.

```dart title="source/main.dart — .environment(...) form (chain reads bottom-up)"
runApp(
  const HomePage()
      // Consumers FIRST (innermost — bottom of the tree).
      .environment(
        (ctx) => MessagesController(backend: ctx.read<ChatBackend>()),
      )
      .environment(
        (ctx) => NavigationController(channels: ctx.read<ChannelsController>()),
      )
      // Dependencies LAST (outermost — ABOVE the consumers).
      .environment((_) => ChannelsController())
      .environment((_) => ChatBackend()),
);
```

```dart title="source/main.dart — MultiProvider form (list reads top-down)"
runApp(
  MultiProvider(
    providers: [
      // Dependencies FIRST (outermost — top of the tree).
      Provider(create: (_) => ChatBackend()),
      Provider(create: (_) => ChannelsController()),
      // Consumers LAST (innermost).
      Provider(
        create: (ctx) =>
            NavigationController(channels: ctx.read<ChannelsController>()),
      ),
      Provider(
        create: (ctx) =>
            MessagesController(backend: ctx.read<ChatBackend>()),
      ),
    ],
    child: const HomePage(),
  ),
);
```

For non-interdependent providers (the original two-line `.environment` example above), order doesn't matter — there's no `ctx.read<T>()` from another provider in the chain.

## 7. Reading reactive state without subscribing — `.untracked`

Docs: <https://solid.mariuti.com/guides/untracked>. Append `.untracked` to read the current value without registering a dependency on the surrounding `build`, effect, or query.

```dart title="source/keyed_container.dart"
class KeyedContainer extends StatelessWidget {
  KeyedContainer({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      // ValueKey reads counter once; it does NOT rebuild on counter changes.
      key: ValueKey(counter.untracked),
      child: const Text('hi'),
    );
  }
}
```

Inside a `@SolidEffect` that writes to a signal, use `.untracked` on the signal you're writing to so the effect doesn't re-trigger itself:

```dart
@SolidState()
List<int> history = [];

@SolidEffect()
void recordHistory() {
  history = [...history.untracked, counter]; // counter tracked, history not
}
```

Reads inside `on*` callback parameters (`onPressed`, `onTap`, `onChanged`, …) are auto-untracked — no `.untracked` needed. In string interpolations, only the long form `'${counter.untracked}'` works; `'$counter.untracked'` is still tracked.
