// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import '../controllers/items_controller.dart';

class SetSignalPage extends StatefulWidget {
  const SetSignalPage({super.key});

  @override
  State<SetSignalPage> createState() => _SetSignalPageState();
}

class _SetSignalPageState extends State<SetSignalPage> {
  late final controller = SetItemsController();

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
      appBar: AppBar(title: const Text('SetSignal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SignalBuilder(
                builder: (context, child) {
                  return ListView.separated(
                    itemCount: controller.items.value.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Text(
                        controller.items.value.elementAt(index).toString(),
                      );
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
