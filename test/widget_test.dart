// TIPO: widget (humo)
// ALCANCE: arranque de la app: abre en la pantalla de inicio
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/widget_test.dart
// DATOS: sin datos externos; el backend responde al instante que no está disponible

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

// El Inicio pide categorías, banners y piezas; aquí ninguna llega, como sin conexión.
class _SinServidor implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => ResponseBody.fromString(
    '{}',
    503,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('La app abre en la pantalla de inicio', (tester) async {
    final storage = MemorySessionStorage();
    final api = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://joyeria.example/api'))..httpClientAdapter = _SinServidor(),
      storage: storage,
    );
    await tester.pumpWidget(JoyeriaApp(storage: storage, apiClient: api));
    await tester.pumpAndSettle();

    // Inicio del boceto P5 (#244): sin sesión invita a entrar y deja explorar el catálogo.
    expect(find.text('JOYERÍA DIANA LAURA'), findsOneWidget);
    expect(find.text('Explorar sin cuenta'), findsOneWidget);
    expect(find.byKey(const Key('nav_inicio')), findsOneWidget);
  });
}
