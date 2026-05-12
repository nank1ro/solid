import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:solid_annotations/solid_annotations.dart';

class ResourcePage extends StatelessWidget {
  const ResourcePage({super.key});

  @SolidState()
  int userId = 1;

  @SolidQuery()
  Future<String> user() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final response = await http.get(
      Uri.parse('https://jsonplaceholder.typicode.com/users/$userId/'),
      headers: {'Accept': 'application/json'},
    );
    return response.body;
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
                userId = intValue;
              },
            ),
            const SizedBox(height: 16),
            user().when(
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
              loading: () => const RepaintBoundary(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
