import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> readJsonBody(HttpRequest request) async {
  final body = await utf8.decoder.bind(request).join();
  final decoded = jsonDecode(body);

  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }

  return {};
}

String decodeBase64QueryParameter(HttpRequest request, String key) {
  final rawValue = request.uri.queryParameters[key];
  if (rawValue == null || rawValue.isEmpty) {
    return "";
  }

  return utf8.decode(base64Decode(rawValue)).trim();
}

Map<String, Object> errorResponse(
  HttpResponse response,
  String message, {
  int statusCode = HttpStatus.badRequest,
}) {
  response.statusCode = statusCode;
  return {
    'ok': false,
    'error': message,
  };
}

Map<String, Object> okResponse() {
  return {'ok': true};
}
