// Patrón Singleton: una sola instancia con la configuración global de la app.
// Se puede cambiar al compilar: flutter run --dart-define=API_URL=http://10.0.2.2:5000/api
class AppConfig {
  AppConfig._interno() : apiBaseUrl = const String.fromEnvironment('API_URL', defaultValue: 'https://joyeria-diana-laura-nqnq.onrender.com/api');

  static final AppConfig instance = AppConfig._interno();

  final String apiBaseUrl;
}
