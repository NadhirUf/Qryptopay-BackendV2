// routes/api/v1/admin/_middleware.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return (context) async {
    // 1. CEK PENTING: Jika browser cuma mau "bertanya" (OPTIONS), biarkan lewat!
    // Biarkan Global Middleware yang menangani jawabannya.
    if (context.request.method == HttpMethod.options) {
      return handler(context);
    }

    // 2. Cek Kunci Rahasia (Hanya untuk GET, POST, dll)
    final adminKey = context.request.headers['x-admin-key'];
    
    // Ganti string ini dengan kunci rahasia yang sama dengan di HTML Anda
    if (adminKey != 'RAHASIA_QARYPTOPAY') {
      return Response(
        statusCode: HttpStatus.forbidden, 
        body: '{"error": "Akses Ditolak: Kunci Salah"}',
      );
    }

    // 3. Jika kunci benar, silakan masuk
    return handler(context);
  };
}