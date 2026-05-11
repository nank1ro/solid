import 'package:http/http.dart' as http;
import 'package:solid_annotations/solid_annotations.dart';

class UserController {
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

  void setUserId(int id) => userId = id;
}
