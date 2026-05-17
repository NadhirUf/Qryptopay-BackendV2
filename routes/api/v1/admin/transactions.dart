// routes/api/v1/admin/transactions.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresClient>();
  final params = context.request.uri.queryParameters;
  final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
  final offset = (int.tryParse(params['page'] ?? '1')! - 1) * limit;

  try {
    // QUERY BARU: Gabungkan User & Merchant
    const query = '''
      SELECT 
        p.created_at,       -- 0. Tanggal
        u.email,            -- 1. Email User
        m.name,             -- 2. Nama Merchant
        p.amount,           -- 3. Jumlah
        p.status            -- 4. Status
      FROM payments p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN merchants m ON p.merchant_id = m.id
      ORDER BY p.created_at DESC
      LIMIT @limit OFFSET @offset
    ''';

    final result = await db.connection.execute(
      Sql.named(query),
      parameters: {'limit': limit, 'offset': offset},
    );

    final List<Map<String, dynamic>> data = result.map((row) {
      // Parsing Amount
      final rawAmount = row[3];
      final amount = (rawAmount is num) 
          ? rawAmount.toDouble() 
          : double.tryParse(rawAmount.toString()) ?? 0.0;

      return {
        'date': row[0].toString(),
        'email': row[1] ?? 'No Email',
        'merchant': row[2] ?? 'Unknown Merchant', // Handle jika merchant dihapus
        'amount': amount,
        'status': row[4],
      };
    }).toList();

    return Response.json(body: {'data': data});

  } catch (e) {
    print('❌ ERROR TRANSAKSI: $e');
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}