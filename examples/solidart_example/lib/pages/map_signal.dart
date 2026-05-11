// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import '../controllers/items_controller.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

class MapSignalPage extends StatefulWidget {
  const MapSignalPage({super.key});

  @override
  State<MapSignalPage> createState() => _MapSignalPageState();
}

class _MapSignalPageState extends State<MapSignalPage> {
  late final controller = MapItemsController();

  String getRandomString(int length) => String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => _chars.codeUnitAt(Random().nextInt(_chars.length)),
    ),
  );

  @override
  void initState() {
    super.initState();
    controller.items.observe((previousValue, value) {
      print('Items changed: $previousValue -> $value');
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapSignal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SignalBuilder(
                builder: (context, child) {
                  final items = controller.items.value;
                  return ListView.separated(
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final key = items.keys.elementAt(index);
                      final value = items[key];
                      return Text('{$key: $value}');
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return const SizedBox(height: 16);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        useLegacyColorScheme: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.remove), label: 'Remove'),
          BottomNavigationBarItem(
            icon: Icon(Icons.clear_all),
            label: 'Clear all',
          ),
        ],
        onTap: (i) {
          switch (i) {
            case 0:
              controller.add(getRandomString(2), Random().nextInt(100));
            case 1:
              controller.removeLast();
            case 2:
              controller.clear();
          }
        },
      ),
    );
  }
}
