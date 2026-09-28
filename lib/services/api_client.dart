import 'package:dio/dio.dart';

import 'session_storage.dart';

// Se puede cambiar al compilar: flutter run --dart-define=API_URL=http://10.0.2.2:5000/api
const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://joyeria-diana-laura-nqnq.onrender.com/api',
);

class ApiClient {
  ApiClient({Dio? dio, SessionStorage? storage})
      : dio = dio ??
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
      this.dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.leerToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ));
    }
  }

  final Dio dio;
}
