import 'package:flutter/material.dart';
import 'package:solid_annotations/extensions.dart';
import 'package:solid_annotations/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

final routes = <String, WidgetBuilder>{
  '/state': (_) => CounterPage(),
  '/computed': (_) => ComputedExample(),
  '/effect': (_) => EffectExample(),
  '/query': (_) => const QueryExample(),
  '/query_with_source': (_) => QueryWithSourceExample(),
  '/query_with_multiple_sources': (_) => QueryWithMultipleSourcesExample(),
  '/environment': (_) => const EnvironmentExample(),
  '/query_with_stream': (_) => const QueryWithStreamExample(),
  '/query_with_stream_and_source': (_) => QueryWithStreamAndSourceExample(),
};

final routeToNameRegex = RegExp('(?:^/|-)([a-zA-Z])');

void main() {
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

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState(name: 'customName')
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateTime.now().toString()),
            Text('Counter: $counter'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => counter++,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

class ComputedExample extends StatelessWidget {
  ComputedExample({super.key});
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
          ready: (data) => Text(data),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ),
    );
  }
}

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
            if (data == null) {
              return const Text('No user ID provided');
            }
            return Text(data);
          },
          loading: () => const CircularProgressIndicator(),
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

class QueryWithMultipleSourcesExample extends StatelessWidget {
  QueryWithMultipleSourcesExample({super.key});

  @SolidState()
  String? userId;

  @SolidState()
  String? authToken;

  @SolidQuery()
  Future<String?> fetchData() async {
    if (userId == null || authToken == null) return null;
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'Fetched Data for $userId';
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
            fetchData().when(
              ready: (data) {
                if (data == null) {
                  return const Text('No user ID provided');
                }
                return Text(data);
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
          authToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class ACustomClassWithSolidState {
  @SolidState()
  int value = 0;

  void dispose() {
    print('ACustomClass disposed');
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
      child: EnvironmentInjectionExample(),
    );
  }
}

class EnvironmentInjectionExample extends StatelessWidget {
  EnvironmentInjectionExample({super.key});

  @SolidEnvironment()
  late ACustomClassWithSolidState myData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Environment')),
      body: Center(child: Text(myData.value.toString())),
      floatingActionButton: FloatingActionButton(
        onPressed: () => myData.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class QueryWithStreamExample extends StatelessWidget {
  const QueryWithStreamExample({super.key});

  @SolidQuery()
  Stream<int> fetchData() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithStream')),
      body: Center(
        child: fetchData().when(
          ready: (data) => Text(data.toString()),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ),
    );
  }
}

class QueryWithStreamAndSourceExample extends StatelessWidget {
  QueryWithStreamAndSourceExample({super.key});

  @SolidState()
  int multiplier = 1;

  @SolidQuery(useRefreshing: false)
  Stream<int> fetchData() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i * multiplier);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QueryWithStream')),
      body: Center(
        child: Column(
          children: [
            Text('Is refreshing: ${fetchData().isRefreshing}'),
            fetchData().when(
              ready: (data) => Text(data.toString()),
              loading: CircularProgressIndicator.new,
              error: (error, stackTrace) => Text('Error: $error'),
            ),
            ElevatedButton(
              onPressed: fetchData.refresh,
              child: const Text('Manual Refresh'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => multiplier++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
