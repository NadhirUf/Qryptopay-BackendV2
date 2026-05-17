// routes/api/v1/fiat/convert.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final db = context.read<PostgresClient>();
    
    // 1. Parse JSON Request
    final body = await context.request.json() as Map<String, dynamic>;
    final int userId = int.parse(body['user_id'].toString());
    final String fromCurrency = body['from_currency'].toString();
    final String toCurrency = body['to_currency'].toString();
    final double amountToConvert = double.parse(body['amount'].toString());

    if (amountToConvert <= 0) {
      return Response.json(statusCode: 400, body: {'error': 'Invalid amount'});
    }

    // 2. Kurs Sama Seperti Balance (Fix Rate Sementara)
    const rates = {
      'IDR': 1.0,
      'USD': 16000.0,
      'JPY': 100.0,
      'THB': 450.0,
      'MYR': 3400.0
    };

    if (!rates.containsKey(fromCurrency) || !rates.containsKey(toCurrency)) {
      return Response.json(statusCode: 400, body: {'error': 'Unsupported currency'});
    }

    // 3. Kalkulasi Nominal & Admin Fee (0.5%)
    double amountInIdr = amountToConvert * rates[fromCurrency]!;
    double convertedAmount = amountInIdr / rates[toCurrency]!;
    double adminFee = convertedAmount * 0.005; // 0.5% Fee
    double finalReceive = convertedAmount - adminFee;

    // 4. Proses Database Transaction
    await db.connection.runTx((ctx) async {
      // A. Kunci row dan cek saldo asal (FOR UPDATE menghindari double spend)
      final checkRes = await ctx.execute(
        Sql.named("SELECT balance FROM fiat_wallets WHERE user_id = @uid AND currency = @curr FOR UPDATE"),
        parameters: {'uid': userId, 'curr': fromCurrency},
      );

      if (checkRes.isEmpty) throw Exception("Wallet $fromCurrency not found");
      
      final currentBalance = double.tryParse(checkRes[0][0].toString()) ?? 0.0;
      if (currentBalance < amountToConvert) {
        throw Exception("Insufficient $fromCurrency balance");
      }

      // B. Potong dari dompet asal
      await ctx.execute(
        Sql.named("UPDATE fiat_wallets SET balance = balance - @amount WHERE user_id = @uid AND currency = @curr"),
        parameters: {'amount': amountToConvert, 'uid': userId, 'curr': fromCurrency},
      );

      // C. Tambah ke dompet tujuan (sudah dipotong fee)
      await ctx.execute(
        Sql.named("UPDATE fiat_wallets SET balance = balance + @receive WHERE user_id = @uid AND currency = @curr"),
        parameters: {'receive': finalReceive, 'uid': userId, 'curr': toCurrency},
      );
    });

    // 5. Berhasil! Kirim Response
    return Response.json(
      body: {
        'status': 'success',
        'message': 'Conversion successful',
        'data': {
          'deducted_amount': amountToConvert,
          'received_amount': finalReceive,
          'fee': adminFee,
          'from_currency': fromCurrency,
          'to_currency': toCurrency
        }
      },
    );
  } catch (e) {
    return Response.json(statusCode: 500, body: {'status': 'error', 'message': e.toString()});
  }
}