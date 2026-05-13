import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/items_controller.dart';

class SetSignalPage extends StatefulWidget {
  const SetSignalPage({super.key});

  @override
  State<SetSignalPage> createState() => _SetSignalPageState();
}

class _SetSignalPageState extends State<SetSignalPage> {
  late final controller = context.read<SetItemsController>();
  late final logItemsChanges = Effect(() {
    debugPrint(
      'Items changed: ${controller.items.previousValue} -> ${controller.items.value}',
    );
  }, name: 'logItemsChanges');

  @override
  void initState() {
    super.initState();
    logItemsChanges;
  }

  @override
  void dispose() {
    logItemsChanges.dispose();
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
                    itemCount: controller.items.length,
                    itemBuilder: (context, index) {
                      return Text(controller.items.elementAt(index).toString());
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
