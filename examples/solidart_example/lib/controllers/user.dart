import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart' as http;
import 'package:solid_annotations/solid_annotations.dart';

class UserController implements Disposable {
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

  void setUserId(int id) => userId.value = id;

  @override
  void dispose() {
    user.dispose();
    userId.dispose();
  }
}
