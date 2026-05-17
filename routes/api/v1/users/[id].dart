// routes/api/v1/users/[id].dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  // 1. Validasi Method: Hanya boleh GET
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final db = context.read<PostgresClient>();

    // 2. Validasi ID User
    final userId = int.tryParse(id);
    if (userId == null) {
      return Response.json(
          statusCode: 400, body: {'message': 'ID User harus angka'});
    }

    // 3. QUERY SAKTI (User + Fiat + Crypto BTC + KYC Status)
    // Kita gunakan LEFT JOIN agar jika wallet belum ada, user tetap ketemu (nilainya null)
    final result = await db.connection.execute(
      Sql.named('''
        SELECT 
            u.full_name, 
            COALESCE(f.balance, 0) as fiat_balance,
            COALESCE(c.balance, 0) as btc_balance,
            u.kyc_status -- 🚨 TAMBAHAN 1: Minta database mengambil kolom kyc_status
        FROM users u
        LEFT JOIN fiat_wallets f ON u.id = f.user_id AND f.currency_code = 'IDR'
        LEFT JOIN crypto_wallets c ON u.id = c.user_id AND c.symbol = 'BTC'
        WHERE u.id = @uid
      '''),
      parameters: {'uid': userId},
    );

    if (result.isEmpty) {
      return Response.json(
          statusCode: 404, body: {'message': 'User tidak ditemukan'});
    }

    final row = result.first;

    // 4. Safe Parsing (Mengamankan Tipe Data Angka)
    // Ambil nama (username)
    final name = row[0]?.toString() ?? 'User';

    // Ambil Saldo Fiat (Rupiah)
    final rawFiat = row[1];
    final balance = (rawFiat is num)
        ? rawFiat.toDouble()
        : double.tryParse(rawFiat?.toString() ?? '0') ?? 0.0;

    // Ambil Saldo BTC (Kripto)
    final rawBtc = row[2];
    final btcBalance = (rawBtc is num)
        ? rawBtc.toDouble()
        : double.tryParse(rawBtc?.toString() ?? '0') ?? 0.0;

    // 🚨 TAMBAHAN 2: Tangkap data kyc_status dari urutan ke-4 (index 3)
    final kycStatus = row[3]?.toString().toUpperCase() ?? 'UNVERIFIED';

    // 5. RETURN DATA SESUAI REQUEST FRONTEND
    return Response.json(
      body: {
        'status': 'SUCCESS',
        'data': {
          'id': userId,
          'name': name,
          'balance': balance, // Saldo Rupiah
          'btc_balance':
              btcBalance, // Saldo Bitcoin (Wajib ada untuk fitur Exchange)
          'kyc_status':
              kycStatus, // 🚨 TAMBAHAN 3: Selipkan statusnya ke paket JSON!
        },
      },
    );
  } catch (e) {
    print('🔥 Error User Detail: $e');
    return Response.json(
      statusCode: 500,
      body: {'message': 'Server Error: $e'},
    );
  }
}
