// lib/services/payment_service.dart
import 'package:qryptopay_backend/models/wallet_models.dart';

class PaymentService {
  /// Proses pembayaran QRIS untuk userId tertentu.
  /// Mengembalikan Map dengan status dan detail saldo.
  Map<String, dynamic> processQrisPayment(String userId, double amountToPay) {
    final fiat = MockDatabase.getFiatFor(userId);
    final crypto = MockDatabase.getCryptoFor(userId);

    print('\n--- TAGIHAN MASUK: Rp $amountToPay ---');

    // Cek Saldo Fiat dulu
    if (fiat.balance >= amountToPay) {
      fiat.balance -= amountToPay;
      return {
        'status': 'SUCCESS',
        'method': 'FIAT_BALANCE',
        'details': {
          'paid': amountToPay,
          'sisa_fiat': fiat.balance,
          'fiat': fiat.toJson(),
        },
      };
    }

    // Jika saldo kurang -> Auto-convert dari crypto
    final deficit = amountToPay - fiat.balance;
    print('Saldo KURANG Rp $deficit. Mencoba Auto-Convert...');

    final pricePerCoin = MockDatabase.currentSolPrice;
    final cryptoNeeded = deficit / pricePerCoin;

    // Tambah buffer 1% untuk cover fluktuasi/fee
    final cryptoToSell = cryptoNeeded * 1.01;

    if (crypto.balance >= cryptoToSell) {
      // Eksekusi jual (mock)
      crypto.balance -= cryptoToSell;

      // Gunakan jumlah crypto yang dijual (cryptoToSell) untuk konversi ke IDR
      final convertedIdr = cryptoToSell * pricePerCoin;

      // Update saldo fiat: tambahkan hasil convert, lalu bayar
      fiat.balance += convertedIdr;
      fiat.balance -= amountToPay;

      return {
        'status': 'SUCCESS',
        'method': 'AUTO_CONVERT_CRYPTO',
        'details': {
          'paid': amountToPay,
          'converted_idr': convertedIdr,
          'sold_crypto': cryptoToSell,
          'crypto_symbol': crypto.symbol,
          'sisa_fiat': fiat.balance,
          'sisa_crypto': crypto.balance,
          'fiat': fiat.toJson(),
          'crypto': crypto.toJson(),
          'price_per_coin': pricePerCoin,
        },
      };
    } else {
      return {
        'status': 'FAILED',
        'message': 'Saldo IDR dan Crypto tidak cukup.',
        'details': {
          'required_crypto': cryptoToSell,
          'available_crypto': crypto.balance,
        },
      };
    }
  }
}