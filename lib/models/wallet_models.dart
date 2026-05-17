// lib/models/wallet_models.dart

class FiatWallet {

  FiatWallet({required this.userId, required this.balance});
  final String userId;
  double balance;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'balance': balance,
        'currency': 'IDR',
      };
}

class CryptoWallet {

  CryptoWallet({required this.userId, required this.symbol, required this.balance});
  final String userId;
  final String symbol;
  double balance;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'symbol': symbol,
        'balance': balance,
      };
}

// Mock Database sederhana
class MockDatabase {
  // Saldo awal untuk testing
  static FiatWallet fiatWallet = FiatWallet(userId: 'user1', balance: 25000);
  static CryptoWallet cryptoWallet = CryptoWallet(userId: 'user1', symbol: 'SOL', balance: 1);

  // Harga 1 SOL = Rp 250.000
  static double currentSolPrice = 250000;

  // Helper untuk ambil wallet berdasarkan userId (saat ini single user mock)
  static FiatWallet getFiatFor(String userId) {
    // Jika nanti mau multiple user, ganti dengan map lookup
    return fiatWallet;
  }

  static CryptoWallet getCryptoFor(String userId) {
    return cryptoWallet;
  }
}