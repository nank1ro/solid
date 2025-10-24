import 'package:test/test.dart';
import 'package:build_test/build_test.dart';

import 'package:solid_generator/src/solid_builder.dart';

void main() {
  group('SolidBuilder', () {
    test('transpiles @SolidState fields to Signal declarations', () async {
      const input = '''
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int count = 0;

  @SolidState(name: 'customCounter')
  int value = 5;
}
''';

      final expectedOutput = '''
import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'package:flutter_solidart/flutter_solidart.dart';

class Counter {
  final count = Signal<int>(0, name: 'count');

  final value = Signal<int>(5, name: 'customCounter');

  void dispose() {
    count.dispose();
    value.dispose();
  }
}
''';

      await testBuilder(
        SolidBuilder(),
        {'a|source/counter.dart': input},
        outputs: {'a|source/counter.solid.dart': expectedOutput},
      );
    });

    test('transpiles @SolidState getters to Computed declarations', () async {
      const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class Calculator {
  @SolidState()
  String firstName = 'John';
        
  @SolidState()
  String lastName = 'Doe';

  @SolidState()
  String get result => firstName + ' ' + lastName;
}
''';

      final expectedOutput = '''
import 'package:solid_annotations/solid_annotations.dart';

import 'package:flutter_solidart/flutter_solidart.dart';

class Calculator {
  final firstName = Signal<String>('John', name: 'firstName');

  final lastName = Signal<String>('Doe', name: 'lastName');

  late final result = Computed<String>(
    () => firstName.value + ' ' + lastName.value,
    name: 'result',
  );

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    result.dispose();
  }
}
''';

      await testBuilder(
        SolidBuilder(),
        {'a|source/calculator.dart': input},
        outputs: {'a|source/calculator.solid.dart': expectedOutput},
      );
    });

    test('transpiles @SolidEffect methods to Effect declarations', () async {
      const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class Logger {
  @SolidEffect()
  void logCounter() {
    print(counter);
  }
}
''';

      final expectedOutput = '''
import 'package:solid_annotations/solid_annotations.dart';

import 'package:flutter_solidart/flutter_solidart.dart';

class Logger {
  late final logCounter = Effect(() {
    print(counter.value);
  }, name: 'logCounter');

  void dispose() {
    logCounter.dispose();
  }
}
''';

      await testBuilder(
        SolidBuilder(),
        {'a|source/logger.dart': input},
        outputs: {'a|source/logger.solid.dart': expectedOutput},
      );
    });

    test('transpiles @SolidQuery methods to Resource declarations', () async {
      const input = '''
import 'package:solid_annotations/solid_annotations.dart';

class DataService {
  @SolidQuery(name: 'userData', debounce: Duration(milliseconds: 300))
  Future<String> fetchUser() async {
    return 'user data';
  }
}
''';

      final expectedOutput = '''
import 'package:solid_annotations/solid_annotations.dart';

import 'package:flutter_solidart/flutter_solidart.dart';

class DataService {
  late final fetchUser = Resource<String>(
    () async {
      return 'user data';
    },
    name: 'userData',
    debounceDelay: const Duration(milliseconds: 300),
  );

  void dispose() {
    fetchUser.dispose();
  }
}
''';

      await testBuilder(
        SolidBuilder(),
        {'a|source/data_service.dart': input},
        outputs: {'a|source/data_service.solid.dart': expectedOutput},
      );
    });
  });

  test('transpiles CounterPage', () async {
    const input = r'''
class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState(name: 'customName')
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reactivity Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Counter: $counter'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => counter++,
              child: const Text('Increment updated'),
            ),
          ],
        ),
      ),
    );
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class CounterPage extends StatefulWidget {
  CounterPage({super.key});

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
      appBar: AppBar(title: const Text('Reactivity Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SignalBuilder(
              builder: (context, child) {
                return Text('Counter: ${counter.value}');
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: const Text('Increment updated'),
            ),
          ],
        ),
      ),
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles ComputedExample', () async {
    const input = r'''
class ComputedExample extends StatelessWidget {
  ComputedExample({super.key});
  @SolidState()
  int counter = 0;

  @SolidState()
  int get doubleCounter => counter * 2;

  @override
  Widget build(BuildContext context) {
    return Text('Counter: $counter, DoubleCounter: $doubleCounter');
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class ComputedExample extends StatefulWidget {
  ComputedExample({super.key});

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
    return SignalBuilder(
      builder: (context, child) {
        return Text(
          'Counter: ${counter.value}, DoubleCounter: ${doubleCounter.value}',
        );
      },
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles EffectExample', () async {
    const input = r'''
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
    return Text('Counter: $counter');
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class EffectExample extends StatefulWidget {
  EffectExample({super.key});

  @override
  State<EffectExample> createState() => _EffectExampleState();
}

class _EffectExampleState extends State<EffectExample> {
  final counter = Signal<int>(0, name: 'counter');
  late final logCounter = Effect(() {
    print('Counter changed: ${counter.value}');
  }, name: 'logCounter');

  @override
  initState() {
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
    return SignalBuilder(
      builder: (context, child) {
        return Text('Counter: ${counter.value}');
      },
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles QueryExample', () async {
    const input = r'''
class QueryExample extends StatelessWidget {
  const QueryExample({super.key});

  @SolidQuery()
  Future<String> fetchData() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }

  @override
  Widget build(BuildContext context) {
    return fetchData().when(
      ready: (data) {
        return Text(data);
      },
      loading: () => CircularProgressIndicator(),
      error: (error, stackTrace) => Text('Error: $error'),
    );
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class QueryExample extends StatefulWidget {
  const QueryExample({super.key});

  @override
  State<QueryExample> createState() => _QueryExampleState();
}

class _QueryExampleState extends State<QueryExample> {
  late final fetchData = Resource<String>(() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }, name: 'fetchData');

  @override
  void dispose() {
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return fetchData().when(
          ready: (data) {
            return Text(data);
          },
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        );
      },
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles QueryWithSourceExample', () async {
    const input = r'''
class QueryWithSourceExample extends StatelessWidget {
  QueryWithSourceExample({super.key});

  @SolidState()
  String? userId;

  @SolidQuery(debounce: Duration(seconds: 1))
  Future<String?> fetchData() async {
    if (userId == null) return null;
    await Future.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }

  @override
  Widget build(BuildContext context) {
    return fetchData().when(
      ready: (data) {
        if (data == null) {
          return const Text('No user ID provided');
        }
        return Text(data);
      },
      loading: () => CircularProgressIndicator(),
      error: (error, stackTrace) => Text('Error: $error'),
    );
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class QueryWithSourceExample extends StatefulWidget {
  QueryWithSourceExample({super.key});

  @override
  State<QueryWithSourceExample> createState() => _QueryWithSourceExampleState();
}

class _QueryWithSourceExampleState extends State<QueryWithSourceExample> {
  final userId = Signal<String?>(null, name: 'userId');
  late final fetchData = Resource<String?>(
    () async {
      if (userId.value == null) return null;
      await Future.delayed(const Duration(seconds: 1));
      return 'Fetched Data';
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
    return SignalBuilder(
      builder: (context, child) {
        return fetchData().when(
          ready: (data) {
            if (data == null) {
              return const Text('No user ID provided');
            }
            return Text(data);
          },
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        );
      },
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles QueryWithMultipleSourcesExample', () async {
    const input = r'''
class QueryWithMultipleSourcesExample extends StatelessWidget {
  QueryWithMultipleSourcesExample({super.key});

  @SolidState()
  String? userId;

  @SolidState()
  String? authToken;

  @SolidQuery()
  Future<String?> fetchData() async {
    if (userId == null || authToken == null) return null;
    await Future.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        Text('Complex Query example'),
        fetchData().when(
          ready: (data) {
            if (data == null) {
              return const Text('No user ID provided');
            }
            return Text(data);
          },
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ],
    );
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class QueryWithMultipleSourcesExample extends StatefulWidget {
  QueryWithMultipleSourcesExample({super.key});

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
      await Future.delayed(const Duration(seconds: 1));
      return 'Fetched Data';
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
    return Column(
      spacing: 8,
      children: [
        Text('Complex Query example'),
        SignalBuilder(
          builder: (context, child) {
            return fetchData().when(
              ready: (data) {
                if (data == null) {
                  return const Text('No user ID provided');
                }
                return Text(data);
              },
              loading: () => CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            );
          },
        ),
      ],
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles ACustomClassWithSolidState', () async {
    const input = r'''
class ACustomClassWithSolidState {
  @SolidState()
  int value = 0;
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class ACustomClassWithSolidState {
  final value = Signal<int>(0, name: 'value');

  void dispose() {
    value.dispose();
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles ACustomClass', () async {
    const input = r'''
class ACustomClass {
  void doNothing() {
    // no-op
  }
}
''';

    final expectedOutput = r'''
class ACustomClass {
  void doNothing() {
    // no-op
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles EnvironmentExample', () async {
    const input = r'''
class EnvironmentExample extends StatelessWidget {
  EnvironmentExample({super.key});

  @SolidEnvironment()
  late ACustomClassWithSolidState myData;

  @override
  Widget build(BuildContext context) {
    return Text(myData.value.toString());
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class EnvironmentExample extends StatefulWidget {
  EnvironmentExample({super.key});

  @override
  State<EnvironmentExample> createState() => _EnvironmentExampleState();
}

class _EnvironmentExampleState extends State<EnvironmentExample> {
  late final myData = context.read<ACustomClassWithSolidState>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(myData.value.value.toString());
      },
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test(
    'transpiles StatefulWidget with existing initState and Effects',
    () async {
      const input = r'''
class EffectExampleWithExistingInitState extends StatefulWidget {
  EffectExampleWithExistingInitState({super.key});

  @override
  State<EffectExampleWithExistingInitState> createState() => _EffectExampleWithExistingInitStateState();
}

class _EffectExampleWithExistingInitStateState extends State<EffectExampleWithExistingInitState> {
  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('Counter changed: $counter');
  }

  @override
  initState() {
    super.initState();
    print('Custom user initialization logic here');
    // User's existing code should be preserved
  }

  @override
  Widget build(BuildContext context) {
    return Text('Counter: $counter');
  }
}
''';

      final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class EffectExampleWithExistingInitState extends StatefulWidget {
  EffectExampleWithExistingInitState({super.key});

  @override
  State<EffectExampleWithExistingInitState> createState() =>
      _EffectExampleWithExistingInitStateState();
}

class _EffectExampleWithExistingInitStateState
    extends State<EffectExampleWithExistingInitState> {
  final counter = Signal<int>(0, name: 'counter');

  late final logCounter = Effect(() {
    print('Counter changed: ${counter.value}');
  }, name: 'logCounter');

  @override
  initState() {
    super.initState();
    logCounter;
    print('Custom user initialization logic here');
    // User's existing code should be preserved
  }

  @override
  void dispose() {
    counter.dispose();
    logCounter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('Counter: ${counter.value}');
      },
    );
  }
}
''';

      await testBuilder(
        SolidBuilder(),
        {'a|source/example.dart': input},
        outputs: {'a|source/example.solid.dart': expectedOutput},
      );
    },
  );

  test('transpiles StatefulWidget with existing dispose method', () async {
    const input = r'''
class EffectExampleWithExistingDispose extends StatefulWidget {
  EffectExampleWithExistingDispose({super.key});

  @override
  State<EffectExampleWithExistingDispose> createState() => _EffectExampleWithExistingDisposeState();
}

class _EffectExampleWithExistingDisposeState extends State<EffectExampleWithExistingDispose> {
  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('Counter changed: $counter');
  }

  @override
  void dispose() {
    print('Custom user disposal logic here');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Counter: $counter');
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class EffectExampleWithExistingDispose extends StatefulWidget {
  EffectExampleWithExistingDispose({super.key});

  @override
  State<EffectExampleWithExistingDispose> createState() =>
      _EffectExampleWithExistingDisposeState();
}

class _EffectExampleWithExistingDisposeState
    extends State<EffectExampleWithExistingDispose> {
  final counter = Signal<int>(0, name: 'counter');

  late final logCounter = Effect(() {
    print('Counter changed: ${counter.value}');
  }, name: 'logCounter');

  @override
  void dispose() {
    print('Custom user disposal logic here');
    counter.dispose();
    logCounter.dispose();
    super.dispose();
  }

  @override
  initState() {
    super.initState();
    logCounter;
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('Counter: ${counter.value}');
      },
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles regular class with existing dispose method', () async {
    const input = r'''
class DataServiceWithExistingDispose {
  @SolidState()
  String? userId;

  @SolidQuery()
  Future<String?> fetchData() async {
    if (userId == null) return null;
    await Future.delayed(const Duration(seconds: 1));
    return 'Fetched Data';
  }

  void dispose() {
    print('Custom user disposal logic here');
    // User's existing disposal code should be preserved
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class DataServiceWithExistingDispose {
  final userId = Signal<String?>(null, name: 'userId');

  late final fetchData = Resource<String?>(
    () async {
      if (userId.value == null) return null;
      await Future.delayed(const Duration(seconds: 1));
      return 'Fetched Data';
    },
    source: userId,
    name: 'fetchData',
  );

  void dispose() {
    print('Custom user disposal logic here');
    // User's existing disposal code should be preserved
    userId.dispose();
    fetchData.dispose();
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles CounterPage with Custom Text widget', () async {
    const input = r'''
class CustomWidget extends StatelessWidget {
  const CustomWidget({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState(name: 'customName')
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reactivity Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomWidget(text: 'Counter: $counter'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => counter++,
              child: const Text('Increment updated'),
            ),
          ],
        ),
      ),
    );
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class CustomWidget extends StatelessWidget {
  const CustomWidget({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}

class CounterPage extends StatefulWidget {
  CounterPage({super.key});

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
      appBar: AppBar(title: const Text('Reactivity Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SignalBuilder(
              builder: (context, child) {
                return CustomWidget(text: 'Counter: ${counter.value}');
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: const Text('Increment updated'),
            ),
          ],
        ),
      ),
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });

  test('transpiles QueryWithStreamExample', () async {
    const input = r'''
class QueryWithStreamExample extends StatelessWidget {
  const QueryWithStreamExample({super.key});

  @SolidQuery(useRefreshing: false)
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
          loading: () => CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Error: $error'),
        ),
      ),
    );
  }
}
''';

    final expectedOutput = r'''
import 'package:flutter_solidart/flutter_solidart.dart';

class QueryWithStreamExample extends StatefulWidget {
  const QueryWithStreamExample({super.key});

  @override
  State<QueryWithStreamExample> createState() => _QueryWithStreamExampleState();
}

class _QueryWithStreamExampleState extends State<QueryWithStreamExample> {
  late final fetchData = Resource<int>.stream(
    () {
      return Stream.periodic(const Duration(seconds: 1), (i) => i);
    },
    name: 'fetchData',
    useRefreshing: false,
  );

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
              loading: () => CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Error: $error'),
            );
          },
        ),
      ),
    );
  }
}
''';

    await testBuilder(
      SolidBuilder(),
      {'a|source/example.dart': input},
      outputs: {'a|source/example.solid.dart': expectedOutput},
    );
  });
}
