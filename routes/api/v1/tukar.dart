// routes/api/v1/tukar.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

// --- DAFTAR HARGA PASAR (DUMMY) ---
const Map<String, double> MARKET_PRICES = {
  'ETH': 30000000.0,
  'BTC': 1500000000.0,
  'SOL': 2000000.0,
};

Future<Response> onRequest(RequestContext context) async {
  // Hanya menerima metode POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    // 1. Ambil data JSON dari aplikasi Flutter
    final body = await context.request.json() as Map<String, dynamic>;
    final userIdStr = context.request.headers['x-user-id'];

    if (userIdStr == null) {
      return Response.json(statusCode: 401, body: {'message': 'Unauthorized'});
    }

    final userId = int.parse(userIdStr);
    final db = context.read<PostgresClient>();

    // --- 2. LOGIKA C2C INOVASI WYIE DIMULAI ---
    final cryptoSymbol = body['crypto_symbol'].toString().toUpperCase();
    final amountCrypto = double.parse(body['crypto_amount'].toString());
    final targetCurrency = body['target_currency'].toString().toUpperCase();

    // A. PENERBANGAN LANGSUNG (Tanpa Stablecoin USDT)
    final rateLangsung = MARKET_PRICES[cryptoSymbol] ?? 0.0;

    // B. Hitung nilai kotor instan
    double nilaiKonversiKotor = amountCrypto * rateLangsung;

    // C. ATURAN BIAYA C2C
    double nilaiBersihUntukUser = 0.0;
    double adminFeeQryptoPay = 0.0;

    if (targetCurrency == 'IDR') {
      // Kasus UMKM Sukoharjo: Potongan fix Rp2.500
      adminFeeQryptoPay = 2500.0;
      nilaiBersihUntukUser = nilaiKonversiKotor - adminFeeQryptoPay;
      print("✅ Mode UMKM Sukoharjo: Fee tetap Rp2.500 diterapkan.");
    } else {
      // Kasus Global (Traveler): Potongan pakai sistem Spread Tipis 0.5%
      adminFeeQryptoPay = nilaiKonversiKotor * 0.005;
      nilaiBersihUntukUser = nilaiKonversiKotor - adminFeeQryptoPay;
      print("✅ Mode Global: Spread 0.5% diterapkan.");
    }

    // Validasi agar saldo tidak minus jika konversi terlalu kecil
    if (nilaiBersihUntukUser <= 0) {
      return Response.json(statusCode: 400, body: {
        'message': 'Jumlah konversi terlalu kecil untuk menutupi biaya admin'
      });
    }

    // --- 3. UPDATE DATABASE (Efek Domino) ---
    // Gunakan runTx (Transaction) agar aman!
    await db.connection.runTx((ctx) async {
      // Step A: Kurangi saldo Crypto turis/user
      await ctx.execute(
        Sql.named(
            'UPDATE crypto_wallets SET balance = balance - @amt WHERE user_id = @uid AND symbol = @sym'),
        parameters: {'amt': amountCrypto, 'uid': userId, 'sym': cryptoSymbol},
      );

      // Step B: Tambahkan saldo bersih (setelah dipotong admin) ke dompet Fiat target
      await ctx.execute(
        Sql.named(
            'UPDATE fiat_wallets SET balance = balance + @net WHERE user_id = @uid AND currency = @code'),
        parameters: {
          'uid': userId,
          'code': targetCurrency,
          'net': nilaiBersihUntukUser
        },
      );

      // Step C: Catat keuntungan aplikasi di terminal (Bisa ditunjukkan ke Juri WYIE)
      print(
          "💰 Keuntungan Perusahaan (C2C Revenue): $adminFeeQryptoPay $targetCurrency");
    });

    // 4. Kembalikan Respon Sukses ke Flutter
    return Response.json(body: {
      'status': 'SUCCESS',
      'message': 'Exchange C2C Berhasil dieksekusi tanpa perantara!',
      'details': {
        'crypto_deducted': amountCrypto,
        'fiat_received': nilaiBersihUntukUser,
        'admin_fee': adminFeeQryptoPay,
        'currency': targetCurrency
      }
    });
  } catch (e) {
    print('!!! Error Exchange C2C: $e');
    return Response.json(statusCode: 500, body: {'message': e.toString()});
  }
}
