import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/extensions.dart';
import 'package:solid_annotations/provider.dart';

final routes = <String, WidgetBuilder>{
  '/state': (_) => const CounterPage(),
  '/computed': (_) => const ComputedExample(),
  '/effect': (_) => const EffectExample(),
  '/query': (_) => const QueryExample(),
  '/query_with_source': (_) => const QueryWithSourceExample(),
  '/query_with_multiple_sources': (_) => const QueryWithMultipleSourcesExample(),
  '/environment': (_) => const EnvironmentExample(),
  '/query_with_stream': (_) => const QueryWithStreamExample(),
  '/query_with_stream_and_source': (_) => const QueryWithStreamAndSourceExample(),
};

final routeToNameRegex = RegExp('(?:^/|-)([a-zA-Z])');

void main() {
  SolidartConfig.autoDispose = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solid Demo',
      home: const MainPage(),
      routes: routes,
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: routes.length,
        itemBuilder: (BuildContext context, int index) {
          final route = routes.keys.elementAt(index);

          final name = route.replaceAllMapped(
            routeToNameRegex,
            (match) => match.group(0)!.substring(1).toUpperCase(),
          );

          return Material(
            child: ListTile(
              title: Text(name),
              onTap: () {
                Navigator.of(context).pushNamed(route);
              },
            ),
          );
        },
      ),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counter = Signal<int>(0, name: 'customName');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateTime.now().toString()),
            SignalBuilder(
              builder: (context, child) {
                return Text('Counter: ${counter.value}');
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

class ComputedExample extends StatefulWidget {
  const ComputedExample({super.key});

  @override
  State<ComputedExample> createState() => _ComputedExampleState();
}

class _ComputedExampleState extends State<ComputedExample> {
  final counter = Signal<int>(0, name: 'counter');
  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );

  @override
  void dispose() {
    counter.dispose();
    doubleCounter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Computed')),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text(
              'Counter: ${counter.value}, DoubleCounter: ${doubleCounter.value}',
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EffectExample extends StatefulWidget {
  const EffectExample({super.key});

  @override
  State<EffectExample> createState() => _EffectExampleState();
}

class _EffectExampleState extends State<EffectExample> {
  final counter = Signal<int>(0, name: 'counter');
  late final logCounter = Effect(() {
    print('Counter changed: ${counter.value}');
  }, name: 'logCounter');

  @override
  void initState() {
    super.initState();
    logCounter;
  }

  @override
  void dispose() {
    counter.dispose();
    logCounter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Effect')),
      body: SignalBuilder(
        builder: (context, child) {
          return Center(child: Text('Counter: ${counter.value}'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class QueryExample extends StatefulWidget {
  const QueryExample({super.key});

  @override
  State<QueryExample> createState() => _QueryExampleState();
}

class _QueryExampleState extends State<QueryExample> {
  late final fetchData = Resource<String>(() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }, name: 'fetchData');

  @override
  void dispose() {
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Query')),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return fetchData().when(
              ready: Text.new,
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            );
          },
        ),
      ),
    );
  }
}

class QueryWithSourceExample extends StatefulWidget {
  const QueryWithSourceExample({super.key});

  @override
  State<QueryWithSourceExample> createState() => _QueryWithSourceExampleState();
}

class _QueryWithSourceExampleState extends State<QueryWithSourceExample> {
  final userId = Signal<String?>(null, name: 'userId');
  late final fetchData = Resource<String?>(
    () async {
      if (userId.value == null) return null;
      await Future<void>.delayed(const Duration(seconds: 1));
      return 'Fetched Data for ${userId.value}';
    },
    source: userId,
    name: 'fetchData',
    debounceDelay: const Duration(seconds: 1),
  );

  @override
  void dispose() {
    userId.dispose();
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithSource')),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return fetchData().when(
              ready: (data) {
                if (data == null) {
                  return const Text('No user ID provided');
                }
                return Text(data);
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            userId.value = 'user_${DateTime.now().millisecondsSinceEpoch}',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class QueryWithMultipleSourcesExample extends StatefulWidget {
  const QueryWithMultipleSourcesExample({super.key});

  @override
  State<QueryWithMultipleSourcesExample> createState() =>
      _QueryWithMultipleSourcesExampleState();
}

class _QueryWithMultipleSourcesExampleState
    extends State<QueryWithMultipleSourcesExample> {
  final userId = Signal<String?>(null, name: 'userId');
  final authToken = Signal<String?>(null, name: 'authToken');
  late final fetchData = Resource<String?>(
    () async {
      if (userId.value == null || authToken.value == null) return null;
      await Future<void>.delayed(const Duration(seconds: 1));
      return 'Fetched Data for ${userId.value}';
    },
    source: Computed(
      () => (userId.value, authToken.value),
      name: 'fetchDataSource',
    ),
    name: 'fetchData',
  );

  @override
  void dispose() {
    userId.dispose();
    authToken.dispose();
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithMultipleSources')),
      body: Center(
        child: Column(
          spacing: 8,
          children: [
            const Text('Complex SolidQuery example'),
            SignalBuilder(
              builder: (context, child) {
                return fetchData().when(
                  ready: (data) {
                    if (data == null) {
                      return const Text('No user ID provided');
                    }
                    return Text(data);
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stackTrace) => Text('Error: $error'),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          userId.value = 'user_${DateTime.now().millisecondsSinceEpoch}';
          authToken.value = 'token_${DateTime.now().millisecondsSinceEpoch}';
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class ACustomClassWithSolidState {
  final value = Signal<int>(0, name: 'value');

  void dispose() {
    print('ACustomClass disposed');
    value.dispose();
  }
}

class ACustomClass {
  void doNothing() {
    // no-op
  }
}

class EnvironmentExample extends StatelessWidget {
  const EnvironmentExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SolidProvider(
      create: (context) => ACustomClassWithSolidState(),
      child: const EnvironmentInjectionExample(),
    );
  }
}

class EnvironmentInjectionExample extends StatefulWidget {
  const EnvironmentInjectionExample({super.key});

  @override
  State<EnvironmentInjectionExample> createState() =>
      _EnvironmentInjectionExampleState();
}

class _EnvironmentInjectionExampleState
    extends State<EnvironmentInjectionExample> {
  late final ACustomClassWithSolidState myData = context.read<ACustomClassWithSolidState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Environment')),
      body: SignalBuilder(
        builder: (context, child) {
          return Center(child: Text(myData.value.value.toString()));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => myData.value.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class QueryWithStreamExample extends StatefulWidget {
  const QueryWithStreamExample({super.key});

  @override
  State<QueryWithStreamExample> createState() => _QueryWithStreamExampleState();
}

class _QueryWithStreamExampleState extends State<QueryWithStreamExample> {
  late final fetchData = Resource<int>.stream(() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'fetchData');

  @override
  void dispose() {
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithStream')),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return fetchData().when(
              ready: (data) => Text(data.toString()),
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            );
          },
        ),
      ),
    );
  }
}

class QueryWithStreamAndSourceExample extends StatefulWidget {
  const QueryWithStreamAndSourceExample({super.key});

  @override
  State<QueryWithStreamAndSourceExample> createState() =>
      _QueryWithStreamAndSourceExampleState();
}

class _QueryWithStreamAndSourceExampleState
    extends State<QueryWithStreamAndSourceExample> {
  final multiplier = Signal<int>(1, name: 'multiplier');
  late final fetchData = Resource<int>.stream(
    () {
      return Stream.periodic(
        const Duration(seconds: 1),
        (i) => i * multiplier.value,
      );
    },
    source: multiplier,
    name: 'fetchData',
    useRefreshing: false,
  );

  @override
  void dispose() {
    multiplier.dispose();
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithStream')),
      body: Center(
        child: Column(
          children: [
            SignalBuilder(
              builder: (context, child) {
                return Text('Is refreshing: ${fetchData().isRefreshing}');
              },
            ),
            SignalBuilder(
              builder: (context, child) {
                return fetchData().when(
                  ready: (data) => Text(data.toString()),
                  loading: CircularProgressIndicator.new,
                  error: (error, stackTrace) => Text('Error: $error'),
                );
              },
            ),
            ElevatedButton(
              onPressed: fetchData.refresh,
              child: const Text('Manual Refresh'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => multiplier.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
