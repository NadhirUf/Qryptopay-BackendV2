// routes/api/v1/transaction/buy.dart

import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
// Sesuaikan jumlah '../' dengan kedalaman folder kamu
import 'package:qryptopay_backend/services/transaction_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Validasi Method: Hanya POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    // 2. Baca Body Request
    final body = await context.request.json();
    final service = context.read<TransactionService>();

    // 3. Validasi Input
    final uid = body['userId'] ?? body['user_id'];
    final symbol = body['symbol'];
    final amount = body['amount']; // Input dalam RUPIAH (IDR)

    if (uid == null || symbol == null || amount == null) {
      return Response.json(
        statusCode: 400, 
        body: {'message': 'Data tidak lengkap. Wajib: userId, symbol, amount (Rupiah)'},
      );
    }

    // 4. Panggil Service BUY
    final result = await service.buyCrypto(
      userId: int.parse(uid.toString()),
      symbol: symbol.toString(),
      fiatAmount: double.parse(amount.toString()),
    );

    return Response.json(body: result);

  } catch (e) {
    print('🔥 Error Buy: $e');
    return Response.json(
      statusCode: 400, 
      body: {'status': 'FAILED', 'message': e.toString().replaceAll('Exception: ', '')},
    );
  }
}