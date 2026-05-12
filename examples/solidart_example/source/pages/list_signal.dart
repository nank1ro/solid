// Observer callbacks print to the console as the simplest demonstration of
// reactive list mutations; production code would route this through a
// proper logger instead.
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import '../controllers/items_controller.dart';

class ListSignalPage extends StatefulWidget {
  const ListSignalPage({super.key});

  @override
  State<ListSignalPage> createState() => _ListSignalPageState();
}

class _ListSignalPageState extends State<ListSignalPage> {
  late final controller = ItemsController();

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
      appBar: AppBar(title: const Text('ListSignal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SignalBuilder(
                builder: (context, child) {
                  return ListView.separated(
                    itemCount: controller.items.value.length,
                    itemBuilder: (context, index) {
                      return Text(controller.items.value[index].toString());
                    },
                    separatorBuilder: (context, index) {
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
