// routes/test_db.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:qryptopay_backend/database/postgres_client.dart'; 

Future<Response> onRequest(RequestContext context) async {
  try {
    // 1. Ambil Instance Singleton
    final db = PostgresClient(); 

    // PENTING: Pastikan init() dipanggil (aman dipanggil berkali-kali)
    await db.init();

    // 2. Cek Koneksi (Ping)
    // Gunakan db.connection.execute
    final result = await db.connection.execute('SELECT 1');

    // 3. Cek Jumlah User
    final userCheck = await db.connection.execute('SELECT count(*) FROM users');

    return Response.json(body: {
      'status': 'OK',
      'message': 'Koneksi Database Berhasil! 🚀',
      // Akses hasil pakai Index [0], bukan nama kolom
      'ping_result': result.first[0], 
      'total_users': userCheck.first[0], 
      'env_host': Platform.environment['DB_HOST'] ?? 'Localhost (Hardcoded)', 
    },);

  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {
        'status': 'ERROR',
        'message': 'Gagal Konek Database 😭',
        'detail': e.toString(),
      },
    );
  }
}