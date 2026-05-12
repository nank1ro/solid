// Observer effect prints to the console as the simplest demonstration of
// reactive map mutations; production code would route this through a
// proper logger instead.
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/items_controller.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

String _randomKey(int length) => String.fromCharCodes(
  Iterable.generate(
    length,
    (_) => _chars.codeUnitAt(Random().nextInt(_chars.length)),
  ),
);

class MapSignalPage extends StatelessWidget {
  const MapSignalPage({super.key});

  @SolidEnvironment()
  late MapItemsController controller;

  @SolidEffect()
  void logItemsChanges() {
    print(
      'Items changed: ${controller.items.previousValue} -> ${controller.items}',
    );
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
              child: ListView.separated(
                itemCount: controller.items.length,
                itemBuilder: (context, index) {
                  final key = controller.items.keys.elementAt(index);
                  final value = controller.items[key];
                  return Text('{$key: $value}');
                },
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 16);
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
              controller.add(_randomKey(2), Random().nextInt(100));
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
