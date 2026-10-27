import 'package:dio/dio.dart';

import 'app_config.dart';
import 'session_storage.dart';

final String apiBaseUrl = AppConfig.instance.apiBaseUrl;

class ApiClient {
  ApiClient({Dio? dio, SessionStorage? storage})
    : _storage = storage,
      dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              // Render apaga el servicio sin uso; la primera petición puede tardar en despertarlo.
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
            ),
          ) {
    if (storage != null) {
      this.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await storage.leerToken();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          },
        ),
      );
    }
  }

  final Dio dio;
  final SessionStorage? _storage;

  // Token de la sesión, para las páginas del backend que se abren en el navegador (recibo).
  Future<String?> token() async => _storage?.leerToken();
}
