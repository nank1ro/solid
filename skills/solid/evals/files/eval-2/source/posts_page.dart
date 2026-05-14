import 'package:flutter/material.dart';

/// Placeholder posts page. The user picks a `userId` via the dropdown,
/// then the body is supposed to show that user's posts — but right now
/// it just shows a static "No user selected" message.
///
/// Extend this widget so that picking a user fetches and displays their
/// posts. Debounce 500ms.
class PostsPage extends StatelessWidget {
  PostsPage({super.key});

  // Available users for the dropdown. Hard-coded for now.
  static const List<String> userIds = ['alice', 'bob', 'charlie'];

  String? selectedUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: Column(
        children: [
          DropdownButton<String>(
            value: selectedUserId,
            hint: const Text('Pick a user'),
            items: userIds
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (id) => selectedUserId = id,
          ),
          const Expanded(child: Center(child: Text('No user selected'))),
        ],
      ),
    );
  }
}
