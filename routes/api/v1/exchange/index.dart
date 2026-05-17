import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
      statusCode: HttpStatus.methodNotAllowed,
      body: {'message': 'Hanya menerima request POST'},
    );
  }

  try {
    final headers = context.request.headers;
    final userIdStr = headers['x-user-id'];

    if (userIdStr == null) {
      return Response.json(statusCode: 401, body: {'message': 'Unauthorized'});
    }
    final userId = int.parse(userIdStr);

    final body = await context.request.json() as Map<String, dynamic>;
    final cryptoSymbol = body['crypto_symbol'].toString();
    final cryptoAmount =
        double.tryParse(body['crypto_amount'].toString()) ?? 0.0;
    final fiatEstimated =
        double.tryParse(body['fiat_estimated'].toString()) ?? 0.0;

    final db = context.read<PostgresClient>();

    await db.connection.runTx((ctx) async {
      // Tahap 1: Cek apakah di tabel crypto_wallets koinnya ada dan cukup?
      final checkBalance = await ctx.execute(
        Sql.named(
            'SELECT balance FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym'),
        parameters: {'uid': userId, 'sym': cryptoSymbol},
      );
      if (checkBalance.isEmpty) {
        throw Exception(
            'Saldo $cryptoSymbol tidak mencukupi (Koin tidak ditemukan)');
      }

      // Kalau datanya kosong atau saldonya kurang, langsung lempar Error!
      final saldoDiDatabase =
          double.tryParse(checkBalance[0][0].toString()) ?? 0.0;

      if (saldoDiDatabase < cryptoAmount) {
        throw Exception('Saldo $cryptoSymbol tidak mencukupi');
      }

      // tahap 2: Kurangi koin di dompet kripto (Ini udah bener banget!)
      await ctx.execute(
        Sql.named(
            'UPDATE crypto_wallets SET balance = balance - @amount WHERE user_id = @uid AND symbol = @sym'),
        parameters: {
          'amount': cryptoAmount,
          'uid': userId,
          'sym': cryptoSymbol
        },
      );

      // Tahap 3: Tambahkan uang Rupiah ke dompet utama
      await ctx.execute(
        Sql.named(
            'UPDATE fiat_wallets SET balance = balance + @fiat WHERE user_id = @uid'), // <--- DIGANTI JADI fiat_wallets
        parameters: {'fiat': fiatEstimated, 'uid': userId},
      );

      // Tahap 4: Masukkan catatan ke tabel transactions biar muncul di HistoryPage
      await ctx.execute(
        Sql.named(
            "INSERT INTO transactions (user_id, type, amount, status, flow, wallet_type, metadata) VALUES (@uid, 'EXCHANGE', @amount,'SUCCESS', 'IN', 'FIAT', @meta)"),
        parameters: {
          'uid': userId,
          'amount': fiatEstimated,
          'meta':
              '{"description": "Exchange $cryptoAmount $cryptoSymbol to IDR"}'
        },
      );
    });

    return Response.json(
      statusCode: HttpStatus.ok,
      body: {'message': 'Exchange berhasil dilakukan!'},
    );
  } catch (e) {
    print('Error Exchange: $e');

    final errorMessage = e.toString().contains('Saldo')
        ? 'Saldo Kripto kamu tidak mencukupi.'
        : 'Terjadi kesalahan sistem database.';

    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'message': errorMessage},
    ); 
  }
}
