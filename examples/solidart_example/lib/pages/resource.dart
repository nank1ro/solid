import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solidart_example/controllers/user.dart';

class ResourcePage extends StatefulWidget {
  const ResourcePage({super.key});

  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  late final controller = UserController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resource')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              initialValue: '1',
              decoration: const InputDecoration(hintText: 'Enter numeric id'),
              onChanged: (s) {
                final intValue = int.tryParse(s);
                if (intValue == null) return;
                controller.setUserId(intValue);
              },
            ),
            const SizedBox(height: 16),
            SignalBuilder(
              builder: (context, child) {
                final userState = controller.user();
                return userState.when(
                  ready: (data) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(data),
                        subtitle:
                            Text('refreshing: ${userState.isRefreshing}'),
                      ),
                      userState.isRefreshing
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: controller.user.refresh,
                              child: const Text('Refresh'),
                            ),
                    ],
                  ),
                  error: (e, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.toString()),
                      userState.isRefreshing
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: controller.user.refresh,
                              child: const Text('Refresh'),
                            ),
                    ],
                  ),
                  loading: () => const RepaintBoundary(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
