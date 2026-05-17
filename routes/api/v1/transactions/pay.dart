// Lokasi: routes/api/v1/transactions/pay.dart

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

    // ===============================================================
    // 2. SMART PARSING (SOLUSI ERROR SALDO KURANG)
    // ===============================================================
    
    // A. Baca Data Wajib (Support camelCase dari Flutter & snake_case)
    final uid = body['userId'] ?? body['user_id'];
    final mid = body['merchantId'] ?? body['merchant_id'];
    final amt = body['amount'];

    if (uid == null || amt == null || mid == null) {
      return Response.json(
        statusCode: 400, 
        body: {'status': 'FAILED', 'message': 'Data userId, amount, atau merchantId kurang lengkap'},
      );
    }

    // B. Baca Data Split Payment (KUNCI UTAMA)
    // Cek key 'isSplit' (Flutter) atau 'is_split' (Legacy)
    var isSplit = false;
    if (body['isSplit'] == true || body['is_split'] == true || body['isSplit'] == 'true') {
      isSplit = true;
    }

    // Cek key 'cryptoAsset'
    final cryptoAsset = body['cryptoAsset'] ?? body['crypto_asset'];

    // Cek key 'fiatAmount' (Flutter) atau 'fiat_used' (Legacy)
    // Ini adalah jumlah Rupiah yang mau ditarik dari Crypto
    double? fiatToConvert;
    final rawFiat = body['fiatAmount'] ?? body['fiat_amount'] ?? body['fiat_used'];
    if (rawFiat != null) {
      fiatToConvert = double.parse(rawFiat.toString());
    }

    // DEBUGGING: Cek di terminal apakah isSplit terbaca true?
    print('DEBUG PAY ROUTE: UID=$uid, Amount=$amt, isSplit=$isSplit, Asset=$cryptoAsset, Convert=$fiatToConvert');

    // ===============================================================
    // 3. PANGGIL SERVICE
    // ===============================================================
    final result = await service.pay(
        userId: int.parse(uid.toString()),        
        amount: double.parse(amt.toString()),      
        merchantId: int.parse(mid.toString()), 
        
        merchantName: body['merchantName']?.toString() ?? body['merchant_name']?.toString(),      
        note: body['note']?.toString(),                       
        
        // Parameter Split Payment yang sudah dibersihkan
        isSplit: isSplit, 
        cryptoAsset: cryptoAsset?.toString(),
        fiatAmount: fiatToConvert,
    );

    return Response.json(body: result);

  } catch (e) {
    print('🔥 Error Pay Endpoint: $e');
    return Response.json(
      statusCode: 500, 
      body: {'status': 'ERROR', 'message': e.toString().replaceAll('Exception: ', '')},
    );
  }
}