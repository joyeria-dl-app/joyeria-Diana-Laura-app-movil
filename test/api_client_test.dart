import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/services/api_client.dart';

void main() {
  test('El cliente apunta al backend de la joyería', () {
    final client = ApiClient();

    expect(client.dio.options.baseUrl, apiBaseUrl);
    expect(client.dio.options.baseUrl, endsWith('/api'));
  });
}
