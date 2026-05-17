import 'package:dart_frog/dart_frog.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';
import 'package:qryptopay_backend/services/admin_service.dart';
import 'package:qryptopay_backend/services/auth_service.dart';
import 'package:qryptopay_backend/services/transaction_service.dart';
import 'package:qryptopay_backend/services/wallet_service.dart';

// Inisialisasi Service (Singleton) agar hemat memori
final _dbClient = PostgresClient();
final _authService = AuthService(_dbClient);
final _trxService = TransactionService(_dbClient);
final _adminService = AdminService(_dbClient);
final _walletService = WalletService(_dbClient);

Handler middleware(Handler handler) {
  // 1. Definisikan Header CORS agar Frontend (port 5500) bisa akses Backend (port 8080)
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, x-admin-key, x-user-id, Authorization',
    'Access-Control-Max-Age': '86400',
  };

  // 2. Bungkus Handler dengan Provider agar bisa di-read di route-route lain
  final pipeline = handler
      .use(requestLogger())
      .use(provider<PostgresClient>((_) => _dbClient))
      .use(provider<AuthService>((_) => _authService))
      .use(provider<TransactionService>((_) => _trxService))
      .use(provider<AdminService>((_) => _adminService))
      .use(provider<WalletService>((_) => _walletService));

  return (context) async {
    // A. HANDLE PREFLIGHT (OPTIONS) - Penting untuk keamanan browser
    if (context.request.method == HttpMethod.options) {
      return Response(headers: corsHeaders);
    }

    try {
      // B. JALANKAN REQUEST ASLI
      final response = await pipeline(context);

      // C. TEMPEL HEADER CORS KE RESPONSE SUKSES
      return response.copyWith(
        headers: {...response.headers, ...corsHeaders},
      );
    } catch (e, stacktrace) {
      // D. JIKA ERROR, TETAP TEMPEL HEADER CORS AGAR ERRORNYA KELIHATAN DI BROWSER
      print('🔥 ERROR SERVER: $e');
      print(stacktrace);

      return Response.json(
        statusCode: 500,
        body: {'status': 'ERROR', 'message': e.toString()},
        headers: corsHeaders,
      );
    }
  };
}
