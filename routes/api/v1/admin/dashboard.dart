// routes/api/v1/admin/dashboard.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:qryptopay_backend/services/admin_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Cek Method (Harus GET)
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    // 2. Ambil Service (Yang sudah di-inject di middleware)
    final service = context.read<AdminService>();

    // 3. Minta Data ke Service
    final stats = await service.getDashboardStats();

    // 4. Kirim Balasan Sukses
    return Response.json(body: {
      'status': 'SUCCESS',
      'data': stats,
    },);

  } catch (e, stacktrace) {
    // 5. Tangkap Error & Print ke Terminal Backend
    print('!!! 💥 CRITICAL ERROR DASHBOARD !!!');
    print('Pesan Error: $e');
    print('Stacktrace: $stacktrace');
    
    // Kirim JSON Error (Biar frontend gak cuma loading terus)
    return Response.json(
      statusCode: 500,
      body: {
        'status': 'ERROR',
        'message': 'Gagal memuat data dashboard',
        'detail': e.toString(), // Ini akan muncul di console browser (admin.html)
      },
    );
  }
}