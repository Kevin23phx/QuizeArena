import 'package:equatable/equatable.dart';

import '../../../../core/storage/token_storage.dart';

final class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  @override
  List<Object?> get props => [id, name, email, role];
}
