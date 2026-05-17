// routes/api/v1/auth/login.dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:qryptopay_backend/services/auth_service.dart';

Future<Response> onRequest(RequestContext context) async {
  // Hanya terima method POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json();
    final authService = context.read<AuthService>();

    // Validasi Input
    if (body['email'] == null || body['password'] == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'message': 'Email dan Password wajib diisi'},
      );
    }

    // Panggil Logic Login
    final result = await authService.login(
      email: body['email'].toString(),
      password: body['password'].toString(),
    );

    return Response.json(body: result);
  } catch (e) {
    print('\n BONGKAR ERROR ASLI : $e\n');

    return Response.json(
      statusCode: HttpStatus.unauthorized, // 401 Unauthorized
      body: {
        'status': 'FAILED',
        'message': e.toString().replaceAll('Exception: ', ''),
      },
    );
  }
}
