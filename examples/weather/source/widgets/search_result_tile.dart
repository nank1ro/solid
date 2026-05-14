import 'package:flutter/material.dart';

import '../domain/city.dart';

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.city,
    required this.alreadyAdded,
    required this.onAdd,
  });

  final City city;
  final bool alreadyAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(city.name),
      subtitle: Text(city.subtitle),
      trailing: alreadyAdded
          ? const Icon(Icons.check, color: Colors.green)
          : const Icon(Icons.add_circle_outline),
      onTap: alreadyAdded ? null : onAdd,
    );
  }
}
