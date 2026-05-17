// routes/api/v1/balance/index.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresClient>();
  final userIdStr = context.request.headers['x-user-id'];
  final userId = int.parse(userIdStr ?? '1');

  try {
    final result = await db.connection.execute(
      Sql.named("SELECT balance, currency_code FROM fiat_wallets WHERE user_id = @uid"),
      parameters: {'uid': userId},
    );

    if (result.isEmpty) {
      return Response.json(body: {'total_fiat_idr': 0.0, 'details': [{'balance': 0.0, 'currency': 'IDR'}]});
    }

    final wallets = result.map((row) {
      return {'balance': double.tryParse(row[0].toString()) ?? 0.0, 'currency': row[1]};
    }).toList();

    double totalInIdr = 0;
    const rates = {'IDR': 1.0, 'USD': 16000.0, 'JPY': 100.0, 'THB': 450.0, 'MYR': 3400.0};

    for (var w in wallets) {
      double rate = rates[w['currency']] ?? 1.0;
      totalInIdr += (w['balance'] as double) * rate;
    }

    return Response.json(body: {'total_fiat_idr': totalInIdr, 'details': wallets});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}
