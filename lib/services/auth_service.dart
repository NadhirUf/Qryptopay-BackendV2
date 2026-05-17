// lib/services/auth_service.dart
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

class AuthService {

  AuthService(this._db);
  final PostgresClient _db;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _db.connection.execute(
      Sql.named(
        'SELECT id, full_name, email, password_hash, role, kyc_level FROM users WHERE email = @email',
      ),
      parameters: {'email': email},
    );

    // 2. Cek apakah email ditemukan
    if (result.isEmpty) {
      throw Exception('Email tidak terdaftar.');
    }

    final user = result.first.toColumnMap();

    // Password disimpan di kolom password_hash (sementara compare plain-text).
    if (user['password_hash'].toString().trim() != password.trim()) {
      throw Exception('Password salah.');
    }

    return {
      'status': 'SUCCESS',
      'message': 'Login Berhasil',
      'data': {
        'id': user['id'],
        'full_name': user['full_name'],
        'email': user['email'],
        'role': user['role'],
        'kyc_level': user['kyc_level'],
      },
    };
  }
}
