// Bottom of the chain: owns `authRepository` through the ordinary `this.x`
// field-formal shape, same as `cross_file_super_param_bare_pure_consumer`.
import 'auth_repository.dart';

class BaseRepository {
  BaseRepository(this.authRepository);

  final AuthRepository authRepository;
}
