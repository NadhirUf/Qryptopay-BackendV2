// routes/api/v1/admin/users.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:qryptopay_backend/database/postgres_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresClient>();

  try {
    final result = await db.connection.execute(
      Sql.named('SELECT id, full_name, email, role, kyc_level FROM users ORDER BY id ASC'),
    );

    final List<Map<String, dynamic>> users = result.map((row) {
      return {
        'id': row[0],
        'name': row[1] ?? 'No Name',
        'email': row[2],
        'role': row[3],
        'status': row[4] ?? 'UNVERIFIED',
      };
    }).toList();

    return Response.json(body: {
      'status': 'SUCCESS', 
      'data': users,
    },);

  } catch (e) {
    print('❌ Error Get Users: $e');
    return Response.json(
      statusCode: 500, 
      body: {'status': 'ERROR', 'error': e.toString()},
    );
  }
}
