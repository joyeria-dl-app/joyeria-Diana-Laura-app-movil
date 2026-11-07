// TIPO: unitaria
// ALCANCE: #93 · el Inicio no avisa a la pantalla si se cerró antes de que llegaran las respuestas
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR. flutter test test/inicio_provider_test.dart
// DATOS: servicios simulados en memoria que responden cuando la prueba lo indica

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/banner_inicio.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/providers/inicio_provider.dart';
import 'package:joyeria_diana_laura/services/inicio_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';

class _Productos implements ProductoService {
  final respuesta = Completer<List<Categoria>>();

  @override
  Future<List<Categoria>> categorias() => respuesta.future;

  @override
  Future<List<Producto>> productos({int? categoriaId, String? busqueda, int pagina = 0}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Inicio implements InicioService {
  @override
  Future<List<BannerInicio>> carrusel() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('si el Inicio se cierra mientras carga, la respuesta tardía no truena', () async {
    final productos = _Productos();
    final inicio = InicioProvider(productos: productos, inicio: _Inicio());

    final carga = inicio.cargar();
    inicio.dispose();
    productos.respuesta.complete(const []);

    await expectLater(carga, completes);
  });
}
