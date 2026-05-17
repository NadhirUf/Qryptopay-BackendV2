import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
// Kita tetap panggil TransactionService karena logika withdraw ada di sana
import 'package:qryptopay_backend/services/transaction_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Validasi Method
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json();
    final service = context.read<TransactionService>();

    // 2. Validasi Input
    if (body['amount'] == null || body['bank'] == null || body['account'] == null) {
      return Response.json(statusCode: 400, body: {'message': 'Data tidak lengkap'});
    }

    // 3. Ambil User ID dengan aman (Support userId / user_id)
    final uid = body['userId'] ?? body['user_id'];
    if (uid == null) throw Exception('User ID tidak ditemukan');

    // 4. Eksekusi Withdraw
    final result = await service.withdraw(
      userId: int.parse(uid.toString()),
      amount: double.parse(body['amount'].toString()),
      bankName: body['bank'].toString(),
      accountNumber: body['account'].toString(),
    );

    return Response.json(body: result);

  } catch (e) {
    print('🔥 Error Withdraw: $e');
    return Response.json(
      statusCode: 400, 
      body: {'status': 'FAILED', 'message': e.toString().replaceAll('Exception: ', '')},
    );
  }
}