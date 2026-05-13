import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/items_controller.dart';

class SetSignalPage extends StatelessWidget {
  const SetSignalPage({super.key});

  @SolidEnvironment()
  late SetItemsController controller;

  @SolidEffect()
  void logItemsChanges() {
    debugPrint(
      'Items changed: ${controller.items.previousValue} -> ${controller.items}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SetSignal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: controller.items.length,
                itemBuilder: (context, index) {
                  return Text(controller.items.elementAt(index).toString());
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
              controller.add(Random().nextInt(100));
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
