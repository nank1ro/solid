import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart' as http;

class ResourcePage extends StatefulWidget {
  const ResourcePage({super.key});

  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  final userId = Signal<int>(1, name: 'userId');
  late final user = Resource<String>(
    () async {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await http.get(
        Uri.parse(
          'https://jsonplaceholder.typicode.com/users/${userId.value}/',
        ),
        headers: {'Accept': 'application/json'},
      );
      return response.body;
    },
    source: userId,
    name: 'user',
  );

  @override
  void dispose() {
    user.dispose();
    userId.dispose();
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
                userId.value = intValue;
              },
            ),
            const SizedBox(height: 16),
            SignalBuilder(
              builder: (context, child) {
                return user().when(
                  ready: (data) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(data),
                        subtitle: Text('refreshing: ${user().isRefreshing}'),
                      ),
                      if (user().isRefreshing)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: user.refresh,
                          child: const Text('Refresh'),
                        ),
                    ],
                  ),
                  error: (e, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.toString()),
                      if (user().isRefreshing)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: user.refresh,
                          child: const Text('Refresh'),
                        ),
                    ],
                  ),
                  loading: () =>
                      const RepaintBoundary(child: CircularProgressIndicator()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
