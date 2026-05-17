// lib/services/wallet_service.dart
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

class WalletService {

  WalletService(this._db);
  final PostgresClient _db;

  // HARGA PASAR DUMMY
  final Map<String, double> cryptoPrices = {
    'BTC': 1500000000.0, // Perbaikan: Harga BTC biasanya Miliar, bukan Juta
    'ETH': 40000000.0,   
    'SOL': 500000.0,     
  };

  

  // ====================================================================
  // 1. FITUR TOP UP (Fix: Hapus source_type)
  // ====================================================================
  Future<Map<String, dynamic>> topUp({
    required int userId,
    required double amount,
    String method = 'BANK_TRANSFER',
  }) async {
    return _db.connection.runTx<Map<String, dynamic>>((session) async {
      
      // A. Ambil Wallet ID
      final walletRes = await session.execute(
        Sql.named('SELECT id, balance FROM fiat_wallets WHERE user_id = @uid FOR UPDATE'),
        parameters: {'uid': userId},
      );

      if (walletRes.isEmpty) throw Exception('Wallet Fiat belum dibuat!');
      final walletId = walletRes.first[0];
      
      // B. Tambah Saldo (Logika Matematika Benar)
      // balance = balance + amount
      await session.execute(
        Sql.named('UPDATE fiat_wallets SET balance = balance + @amt WHERE id = @wid'),
        parameters: {'amt': amount, 'wid': walletId},
      );

      // C. Catat Riwayat (FIX: Hapus source_type, pindahkan ke Note)
      final noteInfo = 'Top Up via $method | Source: EXTERNAL';
      
      await session.execute(
        Sql.named('''
          INSERT INTO payments (user_id, amount, status, description, created_at, note)
          VALUES (@uid, @amt, 'SUCCESS', 'TOP UP', NOW(), @nt)
        '''),
        parameters: {
          'uid': userId,
          'amt': amount,
          'nt': noteInfo, // Info source masuk ke sini
        },
      );

      return {
        'status': 'SUCCESS',
        'message': 'Top Up Berhasil',
        'amount_added': amount,
      };
    });
  }

  // ====================================================================
  // 2. FITUR EXCHANGE (Fix: Hapus source_type)
  // ====================================================================
  Future<Map<String, dynamic>> exchange({
    required int userId,
    required String type,      
    required String symbol,    
    required double amountInput, 
  }) async {
    return _db.connection.runTx<Map<String, dynamic>>((session) async {
      
      // A. Validasi Harga
      final price = cryptoPrices[symbol.toUpperCase()];
      if (price == null) throw Exception('Koin $symbol tidak terdaftar.');

      // B. Ambil Data Wallet Fiat
      final fiatRes = await session.execute(
        Sql.named('SELECT id, balance FROM fiat_wallets WHERE user_id = @uid FOR UPDATE'),
        parameters: {'uid': userId},
      );
      if (fiatRes.isEmpty) throw Exception('Wallet Fiat tidak ditemukan.');
      final fiatId = fiatRes.first[0];
      final currentFiat = (fiatRes.first[1]! as num).toDouble();

      // C. Logic BUY vs SELL
      var description = '';
      var amountResult = 0;

      if (type == 'BUY') {
        // --- SKENARIO BELI (Input Rupiah -> Dapat Koin) ---
        description = 'Buy $symbol';
        
        if (currentFiat < amountInput) {
          throw Exception('Saldo Rupiah tidak cukup untuk beli.');
        }

        amountResult = (amountInput / price).toInt();

        // Potong Rupiah
        await session.execute(
          Sql.named('UPDATE fiat_wallets SET balance = balance - @amt WHERE id = @fid'),
          parameters: {'amt': amountInput, 'fid': fiatId},
        );

        // Tambah Crypto
        await session.execute(
          Sql.named('''
            INSERT INTO crypto_wallets (user_id, symbol, balance)
            VALUES (@uid, @sym, @amt)
            ON CONFLICT (user_id, symbol) 
            DO UPDATE SET balance = crypto_wallets.balance + @amt
          '''),
          parameters: {'uid': userId, 'sym': symbol, 'amt': amountResult},
        );

      } else if (type == 'SELL') {
        // --- SKENARIO JUAL (Input Koin -> Dapat Rupiah) ---
        description = 'Sell $symbol';

        final cryptoRes = await session.execute(
          Sql.named('SELECT id, balance FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym FOR UPDATE'),
          parameters: {'uid': userId, 'sym': symbol},
        );
        
        if (cryptoRes.isEmpty) throw Exception('Kamu belum punya aset $symbol.');
        final cryptoId = cryptoRes.first[0];
        final currentCrypto = (cryptoRes.first[1]! as num).toDouble();

        if (currentCrypto < amountInput) {
           throw Exception('Saldo $symbol tidak cukup.');
        }

        amountResult = (amountInput * price).toInt();

        // Potong Crypto
        await session.execute(
          Sql.named('UPDATE crypto_wallets SET balance = balance - @amt WHERE id = @cid'),
          parameters: {'amt': amountInput, 'cid': cryptoId},
        );

        // Tambah Rupiah
        await session.execute(
          Sql.named('UPDATE fiat_wallets SET balance = balance + @amt WHERE id = @fid'),
          parameters: {'amt': amountResult, 'fid': fiatId},
        );
      } else {
        throw Exception('Tipe transaksi salah (Harus BUY atau SELL)');
      }

      // D. Catat History (FIX: Hapus source_type)
      final noteInfo = 'Rate: 1 $symbol = Rp ${price.toInt()} | Source: EXCHANGE';

      await session.execute(
        Sql.named('''
          INSERT INTO payments (user_id, amount, status, description, created_at, note)
          VALUES (@uid, @amt, 'SUCCESS', @desc, NOW(), @nt)
        '''),
        parameters: {
          'uid': userId,
          'amt': (type == 'BUY') ? amountInput : amountResult, 
          'desc': description,
          'nt': noteInfo, // Info source masuk sini
        },
      );

      return {
        'status': 'SUCCESS',
        'type': type,
        'symbol': symbol,
        'input': amountInput,
        'result': amountResult,
        'message': '$description Berhasil!',
      };
    });
  }
}