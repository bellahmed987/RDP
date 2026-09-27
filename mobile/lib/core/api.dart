import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Api {
  Api._();
  static final instance = Api._();
  static const storage = FlutterSecureStorage();
  String? role;
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8080/api',
      ),
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  Future<void> setToken(String? token) async {
    if (token == null) {
      await storage.delete(key: 'access_token');
      dio.options.headers.remove('Authorization');
    } else {
      await storage.write(key: 'access_token', value: token);
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> restore() async {
    final token = await storage.read(key: 'access_token');
    if (token != null) dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      )).data;
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
    String city,
  ) async => (await dio.post(
    '/auth/register',
    data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'city': city,
    },
  )).data;
  Future<Map<String, dynamic>> me() async => (await dio.get('/auth/me')).data;
}
