import 'dart:io';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final userIdStr = context.request.headers['x-user-id'];
  if (userIdStr == null) {
    return Response.json(
        statusCode: 400, body: {'message': 'Header x-user-id wajib ada'});
  }

  try {
    final db = context.read<PostgresClient>();
    final userId = int.parse(userIdStr);

    // BACA LANGSUNG DARI POSTGRES (Urutkan dari yang terbaru)
    final result = await db.connection.execute(
      Sql.named('''
        SELECT id, amount, type, status, flow, wallet_type, metadata, created_at
        FROM transactions
        WHERE user_id = @uid
        ORDER BY created_at DESC
'''),
      parameters: {'uid': userId},
    );

    // Ubah hasil query SQL jadi format JSON List yang dimengerti Flutter
    final historyList = result.map((row) {
      // Ambil metadata JSON (isinya description "Payment to...")
      var metaMap = <String, dynamic>{};
      if (row[6] != null) {
        try {
          metaMap = jsonDecode(row[6].toString()) as Map<String, dynamic>;
        } catch (e) {}
      }

      return {
        'id': row[0],
        'amount': row[1],
        'type': row[2],
        'status': row[3],
        'flow': row[4],
        'wallet_type': row[5],
        'description': metaMap['description'] ?? 'Transaksi',
        'date': row[7]?.toString() ?? '',
      };
    }).toList();

    return Response.json(body: {
      'status': 'SUCCESS',
      'data': historyList,
    });
  } catch (e) {
    print('Error History: $e');
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}
