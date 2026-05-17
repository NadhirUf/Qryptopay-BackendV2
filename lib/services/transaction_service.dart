import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

class TransactionService {
  TransactionService(this._db);
  final PostgresClient _db;

  // HARGA DUMMY (Nanti ganti dengan API Realtime)
  final Map<String, double> cryptoPrices = {
    'BTC': 1500000000.0,
    'ETH': 40000000.0,
    'SOL': 500000.0,
  };

  // ====================================================================
  // 1. FUNGSI PAY (SMART AUTO-CALCULATE LOGIC)
  // ====================================================================
  Future<Map<String, dynamic>> pay({
    required int userId,
    required double amount, // Tagihan Merchant (IDR)
    required int merchantId,
    String? merchantName,
    String? note,
    bool isSplit = false, // Trigger Auto Convert
    String? cryptoAsset, // Aset crypto (BTC/SOL/ETH)
    double? fiatAmount, // (Opsional) Nominal konversi manual
  }) async {
    return _db.connection.runTx<Map<String, dynamic>>((session) async {
      // A. Validasi & Lock User Fiat Wallet
      final fiatRes = await session.execute(
        Sql.named(
            'SELECT id, balance FROM fiat_wallets WHERE user_id = @uid FOR UPDATE'),
        parameters: {'uid': userId},
      );
      if (fiatRes.isEmpty) throw Exception('Wallet Fiat tidak ditemukan');

      final fiatId = fiatRes.first[0];
      var currentFiat = double.parse(fiatRes.first[1].toString());

      // B. LOGIC KONVERSI PINTAR (AUTO CALCULATE DEFICIT)
      final deficit = amount - currentFiat;

      // Logic: Jalan jika Split ON + Ada Aset + (Saldo Kurang ATAU User minta convert manual)
      if (isSplit &&
          cryptoAsset != null &&
          (deficit > 0 || (fiatAmount != null && fiatAmount > 0))) {
        // Prioritas: Gunakan Defisit agar pas bayar tagihan. Jika tidak defisit, pakai input manual.
        final amountToConvert = deficit > 0 ? deficit : (fiatAmount ?? 0.0);

        if (amountToConvert > 0) {
          // 1. Ambil Harga
          final price = cryptoPrices[cryptoAsset.toUpperCase()] ?? 0.0;
          if (price == 0)
            throw Exception('Harga $cryptoAsset error/tidak tersedia.');

          // 2. Hitung butuh berapa koin?
          final cryptoToDeduct = amountToConvert / price;

          // 3. Lock Crypto Wallet
          final cryptoRes = await session.execute(
            Sql.named(
                'SELECT id, balance FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym FOR UPDATE'),
            parameters: {'uid': userId, 'sym': cryptoAsset},
          );
          if (cryptoRes.isEmpty)
            throw Exception('Wallet $cryptoAsset belum dibuat.');

          final cryptoId = cryptoRes.first[0];
          final currentCrypto = double.parse(cryptoRes.first[1].toString());

          if (currentCrypto < cryptoToDeduct) {
            throw Exception(
                'Saldo $cryptoAsset Kurang. Butuh: ${cryptoToDeduct.toStringAsFixed(6)} $cryptoAsset');
          }

          // 4. EKSEKUSI JUAL CRYPTO (Potong Koin)
          await session.execute(
            Sql.named(
                'UPDATE crypto_wallets SET balance = balance - @amt::numeric WHERE id = @cid'),
            parameters: {'amt': cryptoToDeduct, 'cid': cryptoId},
          );

          // 5. EKSEKUSI TAMBAH FIAT (Topup Virtual)
          await session.execute(
            Sql.named(
                'UPDATE fiat_wallets SET balance = balance + @amt::numeric WHERE id = @fid'),
            parameters: {'amt': amountToConvert, 'fid': fiatId},
          );

          // 6. UPDATE VARIABEL LOKAL (Penting agar logic di bawah valid)
          currentFiat += amountToConvert;

          // 7. Catat Log Konversi (IN)
          final metaConvert = jsonEncode({
            'pair': '${cryptoAsset.toUpperCase()}/IDR',
            'rate': price,
            'action': 'AUTO_CONVERT',
            'description': 'Auto convert $amountToConvert IDR',
          });

          await session.execute(
            Sql.named('''
              INSERT INTO transactions (
                user_id, wallet_id, wallet_type, amount, type, flow, status, metadata, created_at
              ) VALUES (
                @uid, @fid, 'FIAT', @amt::numeric, 'EXCHANGE', 'IN', 'SUCCESS', @meta, NOW()
              )
            '''),
            parameters: {
              'uid': userId,
              'fid': fiatId,
              'amt': amountToConvert,
              'meta': metaConvert
            },
          );
        }
      }

      // C. LOGIC PEMBAYARAN (Bayar Tagihan)

      final double adminFee = 2500.0; //Pajak flat untuk inovasi lomba
      final double totalDebit = amount + adminFee; // Total : Harga + Pajak

      if (currentFiat < totalDebit) {
        throw Exception(
            'Saldo Kurang untuk biaya Admin. Butuh: ${totalDebit.toStringAsFixed(0)}');
      }

      //1. Potong Saldo Fiat (Sekalikus dengan pajaknya)
      await session.execute(
        Sql.named(
            'UPDATE fiat_wallets SET balance = balance - @total::numeric WHERE id = @fid'),
        parameters: {'total': totalDebit, 'fid': fiatId},
      );

      //2. Upsert Merchant (Tetap seperti aslinya)
      final merchantCheck = await session.execute(
        Sql.named('SELECT id FROM merchants WHERE id = @mid'),
        parameters: {'mid': merchantId},
      );
      if (merchantCheck.isEmpty) {
        await session.execute(
          Sql.named(
              'INSERT INTO merchants (id, name, city) VALUES (@mid, @name, @city)'),
          parameters: {
            'mid': merchantId,
            'name': merchantName ?? 'Merchant',
            'city': 'Unknown'
          },
        );
      }

      //3. Catat log pembayaran (Simpan admin_fee ke kolom database!)
      final metaPayment = jsonEncode({
        'merchant_id': merchantId,
        'merchant_name': merchantName ?? 'Unknown Merchant',
        'note': note ?? '',
        'is_split': isSplit,
        'description': 'Payment via Fiat (Pajak Rp$adminFee)',
      });

      await session.execute(
        Sql.named('''
          INSERT INTO transactions (
            user_id, wallet_id, wallet_type, amount, admin_fee, type, flow, status, metadata, created_at
          ) VALUES (
            @uid, @fid, 'FIAT', @amt::numeric, @fee::numeric, 'PAYMENT', 'OUT','SUCCESS',@meta, NOW()
          )
          '''),
        parameters: {
          'uid': userId,
          'fid': fiatId,
          'amt': amount,
          'fee': adminFee, // Ini akan mengisi kolom admin_fee di Pgadmin!
          'meta': metaPayment
        },
      );

      return {
        'status': 'SUCCESS',
        'message': 'Payment Berhasil',
        'data': {
          'transaction_ref': 'TRX-${DateTime.now().millisecondsSinceEpoch}',
          'amount_paid': totalDebit,
          'remaining_fiat_balance': currentFiat - totalDebit,
        },
      };
    });
  }

  // ====================================================================
  // 2. FUNGSI WITHDRAW
  // ====================================================================
  Future<Map<String, dynamic>> withdraw({
    required int userId,
    required double amount,
    required String bankName,
    required String accountNumber,
  }) async {
    return _db.connection.runTx<Map<String, dynamic>>((session) async {
      final walletRes = await session.execute(
        Sql.named(
            'SELECT id, balance FROM fiat_wallets WHERE user_id = @uid FOR UPDATE'),
        parameters: {'uid': userId},
      );

      if (walletRes.isEmpty) throw Exception('Wallet Fiat tidak ditemukan');
      final walletId = walletRes.first[0];
      final currentBalance = double.parse(walletRes.first[1].toString());

      if (currentBalance < amount) throw Exception('Saldo tidak cukup!');

      // Potong Saldo
      await session.execute(
        Sql.named(
            'UPDATE fiat_wallets SET balance = balance - @amt::numeric WHERE id = @wid'),
        parameters: {'amt': amount, 'wid': walletId},
      );

      final metadata = jsonEncode({
        'bank_name': bankName,
        'account_number': accountNumber,
        'description': 'Withdrawal via API',
      });

      // Catat Transaksi
      await session.execute(
        Sql.named('''
          INSERT INTO transactions (
            user_id, wallet_id, wallet_type, amount, type, flow, status, metadata, created_at
          ) VALUES (
            @uid, @wid, 'FIAT', @amt::numeric, 'WITHDRAWAL', 'OUT', 'SUCCESS', @meta, NOW()
          )
        '''),
        parameters: {
          'uid': userId,
          'wid': walletId,
          'amt': amount,
          'meta': metadata
        },
      );

      return {
        'status': 'SUCCESS',
        'message': 'Penarikan Berhasil',
        'remaining_balance': currentBalance - amount,
        'detail': 'Transfer ke $bankName - $accountNumber',
      };
    });
  }

  // ====================================================================
  // 3. FUNGSI EXCHANGE (JUAL CRYPTO KE FIAT - MANUAL)
  // ====================================================================
  Future<Map<String, dynamic>> exchange({
    required int userId,
    required String symbol,
    required double amount, // Jumlah Crypto yg dijual
  }) async {
    return _db.connection.runTx<Map<String, dynamic>>((session) async {
      final pricePerCoin = cryptoPrices[symbol.toUpperCase()] ?? 0.0;
      if (pricePerCoin == 0) throw Exception('Aset $symbol tidak didukung.');

      final totalFiatReceived = amount * pricePerCoin;

      // Cek Crypto Wallet
      final cryptoRes = await session.execute(
        Sql.named(
            'SELECT id, balance FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym FOR UPDATE'),
        parameters: {'uid': userId, 'sym': symbol},
      );

      if (cryptoRes.isEmpty) throw Exception('Wallet $symbol tidak ditemukan.');
      final cryptoId = cryptoRes.first[0];
      final cryptoBalance = double.parse(cryptoRes.first[1].toString());

      if (cryptoBalance < amount) throw Exception('Saldo $symbol tidak cukup.');

      // Potong Crypto
      await session.execute(
        Sql.named(
            'UPDATE crypto_wallets SET balance = balance - @amt::numeric WHERE id = @cid'),
        parameters: {'amt': amount, 'cid': cryptoId},
      );

      // Cek Fiat Wallet
      final fiatRes = await session.execute(
        Sql.named(
            'SELECT id FROM fiat_wallets WHERE user_id = @uid FOR UPDATE'),
        parameters: {'uid': userId},
      );
      if (fiatRes.isEmpty) throw Exception('Wallet Fiat tidak ditemukan.');
      final fiatId = fiatRes.first[0];

      // Tambah Fiat
      await session.execute(
        Sql.named(
            'UPDATE fiat_wallets SET balance = balance + @amt::numeric WHERE id = @fid'),
        parameters: {'amt': totalFiatReceived, 'fid': fiatId},
      );

      final refId = 'EXC-${DateTime.now().millisecondsSinceEpoch}';

      // Log: Crypto Out (Jumlah = Koin)
      final metaCrypto = jsonEncode({
        'pair': '${symbol.toUpperCase()}/IDR',
        'rate': pricePerCoin,
        'action': 'SELL',
        'ref_id': refId,
        'description': 'Sold $amount $symbol',
      });
      await session.execute(
        Sql.named('''
          INSERT INTO transactions (
            user_id, wallet_id, wallet_type, amount, type, flow, status, metadata, created_at
          ) VALUES (
            @uid, @cid, 'CRYPTO', @amt::numeric, 'EXCHANGE', 'OUT', 'SUCCESS', @meta, NOW()
          )
        '''),
        parameters: {
          'uid': userId,
          'cid': cryptoId,
          'amt': amount,
          'meta': metaCrypto
        },
      );

      // Log: Fiat In (Jumlah = Rupiah)
      final metaFiat = jsonEncode({
        'pair': '${symbol.toUpperCase()}/IDR',
        'rate': pricePerCoin,
        'action': 'RECEIVE',
        'ref_id': refId,
        'description': 'Received IDR from selling $symbol',
      });
      await session.execute(
        Sql.named('''
          INSERT INTO transactions (
            user_id, wallet_id, wallet_type, amount, type, flow, status, metadata, created_at
          ) VALUES (
            @uid, @fid, 'FIAT', @amt::numeric, 'EXCHANGE', 'IN', 'SUCCESS', @meta, NOW()
          )
        '''),
        parameters: {
          'uid': userId,
          'fid': fiatId,
          'amt': totalFiatReceived,
          'meta': metaFiat
        },
      );

      return {
        'status': 'SUCCESS',
        'message': 'Berhasil menjual $amount $symbol',
        'received_idr': totalFiatReceived,
        'new_crypto_balance': cryptoBalance - amount,
      };
    });
  }

  // ====================================================================
  // 4. FUNGSI BUY (BELI CRYPTO PAKAI FIAT)
  // ====================================================================
  Future<Map<String, dynamic>> buyCrypto({
    required int userId,
    required String symbol,
    required double fiatAmount, // Beli senilai Rp X
  }) async {
    return _db.connection.runTx<Map<String, dynamic>>((session) async {
      final pricePerCoin = cryptoPrices[symbol.toUpperCase()] ?? 0.0;
      if (pricePerCoin == 0) throw Exception('Aset $symbol tidak didukung.');

      final cryptoReceived = fiatAmount / pricePerCoin;

      // Cek Fiat
      final fiatRes = await session.execute(
        Sql.named(
            'SELECT id, balance FROM fiat_wallets WHERE user_id = @uid FOR UPDATE'),
        parameters: {'uid': userId},
      );
      if (fiatRes.isEmpty) throw Exception('Wallet Fiat tidak ditemukan.');
      final fiatId = fiatRes.first[0];
      final currentFiat = double.parse(fiatRes.first[1].toString());

      if (currentFiat < fiatAmount) {
        throw Exception('Saldo Rupiah tidak cukup.');
      }

      // Potong Fiat
      await session.execute(
        Sql.named(
            'UPDATE fiat_wallets SET balance = balance - @amt::numeric WHERE id = @fid'),
        parameters: {'amt': fiatAmount, 'fid': fiatId},
      );

      // Cek/Create Crypto Wallet
      final cryptoRes = await session.execute(
        Sql.named(
            'SELECT id FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym FOR UPDATE'),
        parameters: {'uid': userId, 'sym': symbol},
      );

      int cryptoId;
      if (cryptoRes.isEmpty) {
        await session.execute(
          Sql.named(
              'INSERT INTO crypto_wallets (user_id, symbol, balance) VALUES (@uid, @sym, 0)'),
          parameters: {'uid': userId, 'sym': symbol},
        );
        final newWallet = await session.execute(
          Sql.named(
              'SELECT id FROM crypto_wallets WHERE user_id = @uid AND symbol = @sym'),
          parameters: {'uid': userId, 'sym': symbol},
        );
        cryptoId = newWallet.first[0]! as int;
      } else {
        cryptoId = cryptoRes.first[0]! as int;
      }

      // Tambah Crypto
      await session.execute(
        Sql.named(
            'UPDATE crypto_wallets SET balance = balance + @amt::numeric WHERE id = @cid'),
        parameters: {'amt': cryptoReceived, 'cid': cryptoId},
      );

      final refId = 'BUY-${DateTime.now().millisecondsSinceEpoch}';

      // Log: Fiat Out (Jumlah = Rupiah)
      final metaFiat = jsonEncode({
        'pair': '${symbol.toUpperCase()}/IDR',
        'rate': pricePerCoin,
        'action': 'BUY',
        'ref_id': refId,
        'description': 'Membeli $cryptoReceived $symbol',
      });
      await session.execute(
        Sql.named('''
          INSERT INTO transactions (
            user_id, wallet_id, wallet_type, amount, type, flow, status, metadata, created_at
          ) VALUES (
            @uid, @fid, 'FIAT', @amt::numeric, 'EXCHANGE', 'OUT', 'SUCCESS', @meta, NOW()
          )
        '''),
        parameters: {
          'uid': userId,
          'fid': fiatId,
          'amt': fiatAmount,
          'meta': metaFiat
        },
      );

      // Log: Crypto In (Jumlah = Koin)
      final metaCrypto = jsonEncode({
        'pair': '${symbol.toUpperCase()}/IDR',
        'rate': pricePerCoin,
        'action': 'RECEIVE',
        'ref_id': refId,
        'description': 'Menerima $symbol dari Pembelian',
      });
      await session.execute(
        Sql.named('''
          INSERT INTO transactions (
            user_id, wallet_id, wallet_type, amount, type, flow, status, metadata, created_at
          ) VALUES (
            @uid, @cid, 'CRYPTO', @amt::numeric, 'EXCHANGE', 'IN', 'SUCCESS', @meta, NOW()
          )
        '''),
        parameters: {
          'uid': userId,
          'cid': cryptoId,
          'amt': cryptoReceived,
          'meta': metaCrypto
        },
      );

      return {
        'status': 'SUCCESS',
        'message':
            'Berhasil membeli ${cryptoReceived.toStringAsFixed(6)} $symbol',
        'spent_idr': fiatAmount,
        'new_crypto_balance': cryptoReceived,
      };
    });
  }

  // ====================================================================
  // 5. FUNGSI GET HISTORY (SMART MAPPING)
  // ====================================================================
  Future<List<Map<String, dynamic>>> getHistory(int userId) async {
    try {
      // Query Union: Menggabungkan tabel 'transactions' baru dengan tabel lama (legacy)
      const sql = '''
        SELECT id:: text, amount, type, wallet_type, status, created_at, metadata:: jsonb
        FROM transactions
        WHERE user_id = @uid
        ORDER BY created_at DESC;
      ''';

      final result = await _db.connection.execute(
        Sql.named(sql),
        parameters: {'uid': userId},
      );

      return result.map((row) {
        final id = row[0].toString();
        // Gunakan tryParse dan toString untuk safety
        final amount = double.tryParse(row[1].toString()) ?? 0.0;
        final type = row[2].toString();
        final walletType = row[3]?.toString() ?? 'FIAT';
        final status = row[4]?.toString() ?? 'PENDING';
        final dateRaw = row[5]! as DateTime;

        // Metadata handling
        var meta = <String, dynamic>{};
        final rawMeta = row[6];
        if (rawMeta != null) {
          if (rawMeta is String) {
            try {
              meta = jsonDecode(rawMeta) as Map<String, dynamic>;
            } catch (_) {}
          } else if (rawMeta is Map) {
            meta = Map<String, dynamic>.from(rawMeta);
          }
        }

        var title = 'Transaksi';
        var description = '-';
        final note = meta['note']?.toString() ?? '-';

        // LOGIC PENAMAAN JUDUL & DESKRIPSI
        if (type == 'PAYMENT') {
          title = meta['merchant_name']?.toString() ?? 'Merchant Payment';
          description = 'Payment via $walletType';
          if (meta['is_split'] == true) description += ' (Split)';
        } else if (type == 'WITHDRAWAL') {
          title = 'Withdraw / Transfer';
          if (meta['is_legacy'] == true) {
            description = 'Riwayat Lama';
          } else {
            description =
                "${meta['bank_name']?.toString() ?? '-'} - ${meta['account_number']?.toString() ?? '-'}";
          }
        } else if (type == 'TOPUP') {
          title = 'Top Up';
          description = meta['provider']?.toString() ?? 'System';
        } else if (type == 'EXCHANGE') {
          final pair = meta['pair']?.toString() ?? '';
          final action = meta['action']?.toString() ?? '';

          if (action == 'SELL') {
            title = 'Jual Crypto';
            // Fix: Gunakan variabel amount agar format double benar
            description = 'Jual $amount ke IDR';
          } else if (action == 'BUY') {
            title = 'Beli Crypto';
            description = meta['description']?.toString() ?? 'Beli $pair';
          } else if (action == 'AUTO_CONVERT') {
            title = 'Auto Convert';
            description =
                meta['description']?.toString() ?? 'Convert for Payment';
          } else {
            title = 'Exchange';
            description = 'Terima IDR dari $pair';
          }
        }

        return {
          'id': id,
          'amount': amount,
          'status': status,
          'type': type,
          // Format tanggal sederhana
          'date':
              "${dateRaw.day}/${dateRaw.month}/${dateRaw.year} ${dateRaw.hour.toString().padLeft(2, '0')}:${dateRaw.minute.toString().padLeft(2, '0')}",
          'title': title,
          'description': description,
          'note': note,
          'source': walletType,
        };
      }).toList();
    } catch (e) {
      print('ERROR GET HISTORY: $e');
      throw Exception('Gagal memuat riwayat: $e');
    }
  }
}
