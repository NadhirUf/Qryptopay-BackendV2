// Lokasi File: routes/api/v1/wallet/exchange.dart

import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
// Pastikan path import ini benar (sesuaikan dengan struktur folder kamu)
import 'package:qryptopay_backend/services/transaction_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Validasi Method: Hanya boleh POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    // 2. Baca Body Request
    final body = await context.request.json();
    final service = context.read<TransactionService>();

    // 3. Validasi Input
    // Kita support 'userId' atau 'user_id' agar fleksibel
    final uid = body['userId'] ?? body['user_id'];
    final symbol = body['symbol'];
    final amount = body['amount'];

    if (uid == null || symbol == null || amount == null) {
      return Response.json(
        statusCode: 400,
        body: {
          'message': 'Data tidak lengkap. Wajib ada: userId, symbol, amount'
        },
      );
    }

    // 4. Eksekusi Service Exchange
    final result = await service.exchange(
      userId: int.parse(uid.toString()), // Safe parsing ke int
      symbol: symbol.toString(), // e.g. "BTC"
      amount: double.parse(amount.toString()), // Safe parsing ke double
    );

    // 5. Return Sukses
    return Response.json(body: result);
  } catch (e) {
    print('🔥 Error Exchange: $e');
    return Response.json(
      statusCode: 400,
      body: {
        'status': 'FAILED',
        'message': e.toString().replaceAll('Exception: ', ''),
      },
    );
  }
}
