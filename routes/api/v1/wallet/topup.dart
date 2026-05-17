// routes/api/v1/wallet/topup.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:qryptopay_backend/services/wallet_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json();
    final service = context.read<WalletService>(); // Panggil Service Baru

    if (body['user_id'] == null || body['amount'] == null) {
      return Response.json(statusCode: 400, body: {'message': 'Data kurang'});
    }

    final result = await service.topUp(
      userId: int.parse(body['user_id'].toString()),
      amount: double.parse(body['amount'].toString()),
      method: body['method']?.toString() ?? 'BANK_TRANSFER',
    );

    return Response.json(body: result);

  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}