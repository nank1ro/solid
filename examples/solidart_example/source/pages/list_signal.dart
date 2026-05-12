import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/items_controller.dart';

class ListSignalPage extends StatelessWidget {
  const ListSignalPage({super.key});

  @SolidEnvironment()
  late ItemsController controller;

  @SolidEffect()
  void logItemsChanges() {
    debugPrint(
      'Items changed: ${controller.items.previousValue} -> ${controller.items}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ListSignal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: controller.items.length,
                itemBuilder: (context, index) {
                  return Text(controller.items[index].toString());
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
          BottomNavigationBarItem(icon: Icon(Icons.sort), label: 'Sort'),
          BottomNavigationBarItem(
            icon: Icon(Icons.clear_all),
            label: 'Clear all',
          ),
        ],
        onTap: (i) {
          switch (i) {
            case 0:
              controller.add(Random().nextInt(100));
            case 1:
              controller.removeLast();
            case 2:
              controller.sort();
            case 3:
              controller.clear();
          }
        },
      ),
    );
  }
}
