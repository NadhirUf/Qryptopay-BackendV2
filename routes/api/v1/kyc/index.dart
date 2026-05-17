import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Cek Metode: Hanya menerima POST (karena ini proses mengirim data/persetujuan)
  if (context.request.method != HttpMethod.post) {
    return Response.json(
        statusCode: HttpStatus.methodNotAllowed,
        body: {'message': 'Hanya menerima request POST'});
  }

  try {
    // 2. Cek Identitas: Mengambil ID User dari header
    final headers = context.request.headers;
    final userIdStr = headers['x-user-id'];
    
    if (userIdStr == null) {
      return Response.json(
          statusCode: HttpStatus.unauthorized, 
          body: {'message': 'Akses ditolak. x-user-id tidak ditemukan.'});
    }
    
    final userId = int.parse(userIdStr);

    // 3. Hubungkan ke Database PostgreSQL
    final db = context.read<PostgresClient>();

    // 4. Eksekusi Perintah SQL: Ubah kyc_status menjadi VERIFIED
    await db.connection.execute(
      Sql.named("UPDATE users SET kyc_status = 'VERIFIED' WHERE id = @uid"),
      parameters: {'uid': userId},
    );

    // 5. Beri laporan balik ke aplikasi HP (Flutter) kalau sudah sukses
    return Response.json(
      statusCode: HttpStatus.ok, 
      body: {
        'message': 'Verifikasi KYC Berhasil! Akun Anda telah disetujui.',
        'status': 'VERIFIED'
      }
    );

  } catch (e) {
    // 6. Tangkap kalau ada error (misal koneksi database putus)
    return Response.json(
        statusCode: HttpStatus.internalServerError,
        body: {'message': 'Gagal melakukan verifikasi KYC: ${e.toString()}'});
  }
}