// routes/api/v1/transaction/sell.dart

import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:qryptopay_backend/services/transaction_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // 1. Validasi Method: Hanya POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json();
    final service = context.read<TransactionService>();

    final uid = body['userId'] ?? body['user_id'];
    final symbol = body['symbol'];
    final amount = body['amount']; // Input dalam JUMLAH COIN (BTC)

    if (uid == null || symbol == null || amount == null) {
      return Response.json(
        statusCode: 400, 
        body: {'message': 'Data tidak lengkap. Wajib: userId, symbol, amount (Crypto)'},
      );
    }

    // 4. Panggil Service EXCHANGE (Logika Jual)
    final result = await service.exchange(
      userId: int.parse(uid.toString()),
      symbol: symbol.toString(),
      amount: double.parse(amount.toString()),
    );

    return Response.json(body: result);

  } catch (e) {
    print('🔥 Error Sell: $e');
    return Response.json(
      statusCode: 400, 
      body: {'status': 'FAILED', 'message': e.toString().replaceAll('Exception: ', '')},
    );
  }
}
