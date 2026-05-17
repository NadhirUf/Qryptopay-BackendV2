// lib/services/admin_service.dart
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

class AdminService {

  AdminService(this._db);
  final PostgresClient _db;

  /// Helper aman untuk konversi ke int
  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// Helper aman untuk konversi ke double
  double _safeDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    print('📊 START: Mengambil Stats Dashboard (Revised)...');
    
    var totalUsers = 0;
    var totalTrx = 0;
    double volume = 0;

    try {
      // 1. HITUNG TOTAL USER
      try {
        final resUser = await _db.connection.execute(Sql.named('SELECT COUNT(*) FROM users'));
        if (resUser.isNotEmpty) {
           totalUsers = _safeInt(resUser.first[0]);
        }
      } catch (e) {
        print('⚠️ Gagal hitung users: $e');
      }

      // 2. HITUNG TOTAL TRANSAKSI (Tabel: payments)
      // PERBAIKAN: Gunakan tabel 'payments', bukan 'transactions'
      try {
        final resTrx = await _db.connection.execute(Sql.named('SELECT COUNT(*) FROM payments'));
        if (resTrx.isNotEmpty) {
           totalTrx = _safeInt(resTrx.first[0]);
        }
      } catch (e) {
         print('⚠️ Gagal hitung transaksi: $e');
      }

      // 3. HITUNG VOLUME UANG MASUK (Hanya yang SUCCESS)
      // PERBAIKAN: 
      // - Gunakan tabel 'payments'
      // - Filter WHERE status = 'SUCCESS' (biar transaksi gagal ga dihitung)
      try {
        final resVol = await _db.connection.execute(
          Sql.named("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'SUCCESS'"),
        );
        if (resVol.isNotEmpty) {
           volume = _safeDouble(resVol.first[0]);
        }
      } catch (e) {
         print('⚠️ Gagal hitung volume: $e');
      }

      print('✅ DONE: Users=$totalUsers, Trx=$totalTrx, Vol=$volume');

      return {
        'status': 'SUCCESS',
        'total_users': totalUsers,
        'total_transactions': totalTrx,
        'transaction_volume': volume,
        'last_updated': DateTime.now().toIso8601String(),
      };

    } catch (e, stack) {
      print('🔥 FATAL ERROR di AdminService: $e');
      print(stack);
      
      return {
        'status': 'PARTIAL_ERROR',
        'error_msg': e.toString(),
        'total_users': 0,       
        'total_transactions': 0, 
        'transaction_volume': 0,
      };
    }
  }
}