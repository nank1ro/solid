import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controllers/computed_value.dart';
import 'controllers/counter.dart';
import 'controllers/effects.dart';
import 'controllers/items_controller.dart';
import 'controllers/lazy_counter.dart';
import 'pages/computed.dart';
import 'pages/counter.dart';
import 'pages/effects.dart';
import 'pages/lazy_counter.dart';
import 'pages/list_signal.dart';
import 'pages/map_signal.dart';
import 'pages/resource.dart';
import 'pages/set_signal.dart';
import 'pages/signal_builder.dart';

class Logger implements SolidartObserver {
  @override
  void didCreateSignal(SignalBase<Object?> signal) {
    final value = signal.hasValue ? signal.value : 'undefined';
    dev.log('didCreateSignal(name: ${signal.name}, value: $value)');
  }

  @override
  void didDisposeSignal(SignalBase<Object?> signal) {
    dev.log('didDisposeSignal(name: ${signal.name})');
  }

  @override
  void didUpdateSignal(SignalBase<Object?> signal) {
    dev.log(
      'didUpdateSignal(name: ${signal.name}, previousValue: ${signal.previousValue}, value: ${signal.value})',
    );
  }
}

void main() {
  SolidartConfig.observers.add(Logger());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Solid Flutter Demo',
      theme: ThemeData(useMaterial3: false, primarySwatch: Colors.blue),
      home: const HomePage(),
      routes: routes,
    );
  }
}

final routes = <String, WidgetBuilder>{
  '/counter': (_) => const CounterPage().environment(
    (_) => CounterController(),
    dispose: (context, provider) => provider.dispose(),
  ),
  '/lazy-counter': (_) => const LazyCounterPage().environment(
    (_) => LazyCounterController(),
    dispose: (context, provider) => provider.dispose(),
  ),
  '/computed': (_) => const ComputedPage().environment(
    (_) => ComputedValueController(),
    dispose: (context, provider) => provider.dispose(),
  ),
  '/effects': (_) => const EffectsPage().environment(
    (_) => EffectsController(),
    dispose: (context, provider) => provider.dispose(),
  ),
  '/signal-builder': (_) => const SignalBuilderPage(),
  '/resource': (_) => const ResourcePage(),
  '/list-signal': (_) => const ListSignalPage().environment(
    (_) => ItemsController(),
    dispose: (context, provider) => provider.dispose(),
  ),
  '/set-signal': (_) => const SetSignalPage().environment(
    (_) => SetItemsController(),
    dispose: (context, provider) => provider.dispose(),
  ),
  '/map-signal': (_) => const MapSignalPage().environment(
    (_) => MapItemsController(),
    dispose: (context, provider) => provider.dispose(),
  ),
};

final routeToNameRegex = RegExp('(?:^/|-)([a-z])');

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final keys = routes.keys;
    return Scaffold(
      appBar: AppBar(title: const Text('Solid showcase')),
      body: ListView.builder(
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = keys.elementAt(index);

          final name = route.replaceAllMapped(
            routeToNameRegex,
            (match) => match.group(0)!.substring(1).toUpperCase(),
          );

          return ListTile(
            title: Text(name),
            onTap: () {
              unawaited(Navigator.of(context).pushNamed(route));
            },
          );
        },
      ),
    );
  }
}
