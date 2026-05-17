// lib/services/user_service.dart

import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

class UserService {

  UserService(this._db);
  final PostgresClient _db;

  Future<Map<String, dynamic>> getProfileWithBalances(int userId) async {
    // 1. Ambil Data User
    final userResult = await _db.connection.execute(
      Sql.named('SELECT id, name, email FROM users WHERE id = @uid'),
      parameters: {'uid': userId},
    );

    if (userResult.isEmpty) {
      throw Exception('User tidak ditemukan');
    }

    final userRow = userResult.first;

    // 2. Ambil Saldo Rupiah (Fiat)
    final fiatResult = await _db.connection.execute(
      Sql.named('SELECT balance FROM fiat_wallets WHERE user_id = @uid'),
      parameters: {'uid': userId},
    );
    // Jika belum punya wallet, saldo 0
    final fiatBalance = fiatResult.isNotEmpty 
        ? double.parse(fiatResult.first[0].toString()) 
        : 0.0;

    // 3. Ambil Saldo Bitcoin (BTC) khusus
    // (Sesuai permintaan checklist: btc_balance)
    final btcResult = await _db.connection.execute(
      Sql.named("SELECT balance FROM crypto_wallets WHERE user_id = @uid AND symbol = 'BTC'"),
      parameters: {'uid': userId},
    );
    final btcBalance = btcResult.isNotEmpty 
        ? double.parse(btcResult.first[0].toString()) 
        : 0.0;

    // 4. Rakit JSON Sesuai Permintaan Frontend
    return {
      'data': {
        'id': userRow[0],
        'name': userRow[1],
        'email': userRow[2],
        'balance': fiatBalance,      // <-- Saldo Rupiah
        'btc_balance': btcBalance,    // <-- Saldo BTC (Request Frontend terpenuhi!)
      },
    };
  }
}