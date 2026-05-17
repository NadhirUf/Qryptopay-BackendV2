// routes/api/v1/wallets/crypto/[id].dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

// --- DAFTAR HARGA PASAR (DUMMY) ---
const Map<String, double> MARKET_PRICES = {
  'ETH': 30000000.0,
  'ETHEREUM': 30000000.0,
  'BTC': 1500000000.0,
  'BITCOIN': 1500000000.0,
  'SOL': 2000000.0,
  'SOLANA': 2000000.0,
};

Future<Response> onRequest(RequestContext context, String id) async {
  // 1. Cek Method
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // 2. AMBIL KONEKSI
  final db = context.read<PostgresClient>();
  final userId = int.tryParse(id);

  if (userId == null) {
    // PERBAIKAN: Pastikan ada kata '.json' di sini 👇
    return Response.json(statusCode: 400, body: {'message': 'Invalid User ID'});
  }

  print('\n--- 🕵️ MULAI INVESTIGASI USER ID: $userId ---');

  try {
    // 3. Ambil data
    final result = await db.connection.execute(
      Sql.named(
          'SELECT symbol, balance FROM crypto_wallets WHERE user_id = @uid'),
      parameters: {'uid': userId},
    );

    final assets = <Map<String, dynamic>>[];

    // KASUS 1: Database Kosong
    if (result.isEmpty) {
      print(
          '❌ HASIL KOSONG: Tidak ada data di tabel crypto_wallets untuk User ID $userId.');
    }

    for (final row in result) {
      final rawSymbol = row[0].toString();
      final rawBalance = row[1];

      final double balance = double.tryParse(rawBalance.toString()) ?? 0.0;
      print("🔎 DITEMUKAN: Symbol=['$rawSymbol'] | Balance=['$balance']");

      final symbolKey = rawSymbol.trim().toUpperCase();
      final price = MARKET_PRICES[symbolKey] ?? 0.0;

      if (price == 0) {
        print("   ⚠️ PERINGATAN: Harga 0 untuk '$symbolKey'.");
      } else {
        print("   ✅ INFO: Harga '$symbolKey' = Rp $price");
      }

      final double estimatedIdr = balance * price;

      assets.add({
        'symbol': rawSymbol,
        'balance': balance,
        'estimated_idr': estimatedIdr,
      });
    }

    print('--- 🏁 SELESAI: Mengirim ${assets.length} Aset ke Frontend ---\n');

    // Pastikan ini juga pakai .json
    return Response.json(
      body: {
        'status': 'SUCCESS',
        'data': assets,
      },
    );
  } catch (e) {
    print('!!! 💥 ERROR FATAL !!! : $e');
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}
