// TIPO: unitaria
// ALCANCE: HU-01 · cliente HTTP: dirección del backend y encabezado con el token
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/api_client_test.dart
// DATOS: sin datos externos

import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/services/api_client.dart';

void main() {
  test('El cliente apunta al backend de la joyería', () {
    final client = ApiClient();

    expect(client.dio.options.baseUrl, apiBaseUrl);
    expect(client.dio.options.baseUrl, endsWith('/api'));
  });
}
