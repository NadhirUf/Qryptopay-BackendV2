import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(
        statusCode: HttpStatus.methodNotAllowed,
        body: {'message': 'Hanya POST'});
  }

  try {
    final headers = context.request.headers;
    final userIdStr = headers['x-user-id'];
    if (userIdStr == null)
      return Response.json(statusCode: 401, body: {'message': 'Unauthorized'});
    final userId = int.parse(userIdStr);

    final body = await context.request.json() as Map<String, dynamic>;

    // 🚨 DATA DARI FLUTTER
    final amountPay = double.tryParse(body['amount'].toString()) ?? 0.0;
    final merchantName = body['merchant_name']?.toString() ?? 'Unknown Merchant';
    final currencyCode = body['currency']?.toString().toUpperCase() ?? 'IDR';
    
    // 👇 KUNCI RAHASIA AUTO-CONVERT DITANGKAP DI SINI
    final isAutoConvert = body['is_auto_convert'] == true;
    final cryptoSymbol = body['crypto_symbol']?.toString().toUpperCase();

    if (amountPay <= 0) throw Exception('Nominal tagihan tidak valid');

    final db = context.read<PostgresClient>();

    await db.connection.runTx((ctx) async {
      
      // ==========================================================
      // JALUR 1: PEMBAYARAN AUTO-CONVERT (PAKAI ASET KRIPTO)
      // ==========================================================
      if (isAutoConvert && cryptoSymbol != null) {
        
        // --- A. Hitung Kurs Dummy (Sama seperti Kalkulator di Frontend) ---
        double fiatRateToIdr = 1.0; 
        if (currencyCode == 'USD') fiatRateToIdr = 16000.0;
        if (currencyCode == 'JPY') fiatRateToIdr = 105.0;
        if (currencyCode == 'MYR') fiatRateToIdr = 3400.0;
        if (currencyCode == 'THB') fiatRateToIdr = 430.0;

        // Asumsi harga 1 Koin dalam Rupiah (Bisa disesuaikan)
        double cryptoRateInIdr = 1.0;
        if (cryptoSymbol == 'BTC') cryptoRateInIdr = 1000000000.0; // 1 Miliar
        if (cryptoSymbol == 'ETH') cryptoRateInIdr = 50000000.0;   // 50 Juta
        if (cryptoSymbol == 'SOL') cryptoRateInIdr = 2500000.0;    // 2.5 Juta

        // Rumus: (Tagihan Asing -> IDR) lalu (IDR -> Nilai Potongan Kripto)
        double tagihanIdr = amountPay * fiatRateToIdr;
        double cryptoYangDipotong = tagihanIdr / cryptoRateInIdr;

        // --- B. Cek Dompet Kripto ---
        final checkCrypto = await ctx.execute(
          Sql.named("SELECT balance FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym"),
          parameters: {'uid': userId, 'sym': cryptoSymbol},
        );

        if (checkCrypto.isEmpty) throw Exception('Dompet $cryptoSymbol tidak ditemukan');
        double cryptoBalance = double.tryParse(checkCrypto[0][0].toString()) ?? 0.0;

        if (cryptoBalance < cryptoYangDipotong) {
          throw Exception('Saldo $cryptoSymbol tidak mencukupi untuk Auto-Convert');
        }

        // --- C. Potong Saldo Kripto ---
        await ctx.execute(
          Sql.named("UPDATE crypto_wallets SET balance = balance - @amount WHERE user_id = @uid AND symbol = @sym"),
          parameters: {'amount': cryptoYangDipotong, 'uid': userId, 'sym': cryptoSymbol},
        );

        // --- D. Catat Transaksi (Sebagai Tipe Crypto) ---
        await ctx.execute(
          Sql.named("INSERT INTO transactions (user_id, type, amount, status, flow, wallet_type, metadata) VALUES (@uid, 'PAYMENT', @amount, 'SUCCESS', 'OUT', 'CRYPTO', @meta)"),
          parameters: {
            'uid': userId,
            'amount': cryptoYangDipotong,
            'meta': '{"description": "Auto-Convert to $currencyCode for $merchantName", "currency": "$cryptoSymbol"}'
          },
        );

      } 
      // ==========================================================
      // JALUR 2: PEMBAYARAN NORMAL (PAKAI UANG TUNAI/FIAT)
      // ==========================================================
      else {
        final checkBalance = await ctx.execute(
          Sql.named("SELECT balance FROM fiat_wallets WHERE user_id = @uid AND currency_code = @code"),
          parameters: {'uid': userId, 'code': currencyCode},
        );

        if (checkBalance.isEmpty) throw Exception('Dompet $currencyCode tidak ditemukan');
        final saldoDiDatabase = double.tryParse(checkBalance[0][0].toString()) ?? 0.0;

        if (saldoDiDatabase < amountPay) {
          throw Exception('Saldo $currencyCode tidak mencukupi untuk pembayaran ini');
        }

        // Potong Saldo Fiat
        await ctx.execute(
          Sql.named("UPDATE fiat_wallets SET balance = balance - @amount WHERE user_id = @uid AND currency_code = @code"),
          parameters: {'amount': amountPay, 'uid': userId, 'code': currencyCode},
        );

        // Catat Transaksi
        await ctx.execute(
          Sql.named("INSERT INTO transactions (user_id, type, amount, status, flow, wallet_type, metadata) VALUES (@uid, 'PAYMENT', @amount, 'SUCCESS', 'OUT', 'FIAT', @meta)"),
          parameters: {
            'uid': userId,
            'amount': amountPay,
            'meta': '{"description": "Payment to $merchantName", "currency": "$currencyCode"}'
          },
        );
      }
    });

    // Berikan respons sukses ke aplikasi HP
    String metodeBayar = isAutoConvert ? "Auto-Convert ($cryptoSymbol)" : currencyCode;
    return Response.json(statusCode: HttpStatus.ok, body: {
      'message': 'Pembayaran $amountPay $currencyCode via $metodeBayar Berhasil!'
    });

  } catch (e) {
    return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'message': e.toString().replaceAll('Exception: ', '')});
  }
}