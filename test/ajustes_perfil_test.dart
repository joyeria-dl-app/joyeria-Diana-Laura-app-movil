// TIPO: widget
// ALCANCE: HU-14 · Ajustes del perfil (#213): editar nombre y teléfono con las reglas del sitio web y cambiar la foto de perfil
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/ajustes_perfil_test.dart
// DATOS: backend simulado en memoria (sin red); perfil de ejemplo y foto de 3 bytes en lugar de la galería

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/perfil.dart';
import 'package:joyeria_diana_laura/screens/perfil_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/perfil_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/utils/validaciones.dart';

// Perfil en memoria: guarda lo que se actualiza y lo devuelve en la siguiente consulta.
class _PerfilFalso extends PerfilService {
  _PerfilFalso()
    : super(
        api: ApiClient(),
        pedidos: PedidoService(api: ApiClient()),
        favoritos: FavoritoService(api: ApiClient()),
      );

  Map<String, Object?> cuenta = {
    'nombre': 'Ana Martínez',
    'email': 'ana.martinez@correo.com',
    'telefono': '7711234567',
    'foto_perfil_url': null,
    'fecha_creacion': '2026-10-02T15:20:00.000Z',
  };
  final List<Map<String, String?>> actualizaciones = [];
  final List<String> fotosSubidas = [];
  PerfilException? errorAlGuardar;

  @override
  Future<Perfil> perfil() async => Perfil.fromJson(cuenta);

  @override
  Future<ResumenCliente> resumen() async => const ResumenCliente(pedidos: 3, apartados: 2, favoritos: 8);

  @override
  Future<void> actualizar({String? nombre, String? telefono, String? fotoUrl}) async {
    if (errorAlGuardar != null) throw errorAlGuardar!;
    actualizaciones.add({'nombre': nombre, 'telefono': telefono, 'foto': fotoUrl});
    cuenta = {...cuenta, 'nombre': ?nombre, if (telefono != null) 'telefono': telefono.isEmpty ? null : telefono, 'foto_perfil_url': ?fotoUrl};
  }

  @override
  Future<String> subirFoto(List<int> bytes, String nombreArchivo) async {
    fotosSubidas.add(nombreArchivo);
    return 'https://res.cloudinary.com/tienda/image/upload/joyeria/usuarios/$nombreArchivo';
  }
}

Future<void> _abrir(WidgetTester tester, PerfilService servicio) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<PerfilService>.value(
      value: servicio,
      child: MaterialApp(theme: AppTheme.oscuro(), home: const PerfilScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirAjustes(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes'));
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String campo, String texto) async {
  await tester.enterText(find.descendant(of: find.byKey(Key(campo)), matching: find.byType(TextFormField)), texto);
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('ajustes_guardar')));
  await tester.tap(find.byKey(const Key('ajustes_guardar')));
  await tester.pumpAndSettle();
}

void main() {
  group('Reglas del teléfono', () {
    test('Es opcional y acepta 10 dígitos con espacios o guiones', () {
      expect(Validaciones.telefono(''), isNull);
      expect(Validaciones.telefono('7711234567'), isNull);
      expect(Validaciones.telefono('771 123 4567'), isNull);
      expect(Validaciones.telefono('771-123-4567'), isNull);
      expect(Validaciones.soloDigitos('771-123 4567'), '7711234567');
    });

    test('Rechaza menos o más de 10 dígitos y letras', () {
      for (final malo in ['771123456', '77112345678', '77112345ab', '+527711234567']) {
        expect(Validaciones.telefono(malo), 'El teléfono debe tener 10 dígitos', reason: malo);
      }
    });
  });

  testWidgets('El engrane abre Ajustes con el nombre, el teléfono y el correo de la cuenta', (tester) async {
    await _abrir(tester, _PerfilFalso());
    await _abrirAjustes(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Ana Martínez'), findsOneWidget);
    expect(find.text('7711234567'), findsOneWidget);
    expect(find.text('ana.martinez@correo.com'), findsOneWidget);
    expect(find.text('El correo es el de tu cuenta y no se cambia desde aquí.'), findsOneWidget);
  });

  testWidgets('Guarda el nombre y el teléfono nuevos y Mi perfil los muestra', (tester) async {
    final servicio = _PerfilFalso();
    await _abrir(tester, servicio);
    await _abrirAjustes(tester);
    await _escribir(tester, 'ajustes_nombre', 'Ana Laura Martínez');
    await _escribir(tester, 'ajustes_telefono', '771 765 4321');
    await _guardar(tester);

    expect(servicio.actualizaciones, [
      {'nombre': 'Ana Laura Martínez', 'telefono': '7717654321', 'foto': null},
    ]);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Ana Laura Martínez'), findsOneWidget);
    expect(find.text('Tus datos se guardaron'), findsOneWidget);
  });

  testWidgets('Solo envía lo que cambió y el teléfono vacío lo borra', (tester) async {
    final servicio = _PerfilFalso();
    await _abrir(tester, servicio);
    await _abrirAjustes(tester);
    await _escribir(tester, 'ajustes_telefono', '');
    await _guardar(tester);

    expect(servicio.actualizaciones, [
      {'nombre': null, 'telefono': '', 'foto': null},
    ]);
  });

  testWidgets('Sin cambios regresa sin llamar al backend', (tester) async {
    final servicio = _PerfilFalso();
    await _abrir(tester, servicio);
    await _abrirAjustes(tester);
    await _guardar(tester);

    expect(servicio.actualizaciones, isEmpty);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Tus datos se guardaron'), findsNothing);
  });

  testWidgets('Con datos inválidos muestra el error y no guarda', (tester) async {
    final servicio = _PerfilFalso();
    await _abrir(tester, servicio);
    await _abrirAjustes(tester);
    await _escribir(tester, 'ajustes_nombre', 'An');
    await _escribir(tester, 'ajustes_telefono', '77123');
    await _guardar(tester);

    expect(find.text('El nombre debe tener al menos 3 caracteres'), findsOneWidget);
    expect(find.text('El teléfono debe tener 10 dígitos'), findsOneWidget);
    expect(servicio.actualizaciones, isEmpty);

    // Al corregir el teléfono su error se quita sin volver a tocar Guardar.
    await _escribir(tester, 'ajustes_telefono', '7711234567');
    await tester.pump();
    expect(find.text('El teléfono debe tener 10 dígitos'), findsNothing);

    await _escribir(tester, 'ajustes_nombre', 'Ana 2');
    await _guardar(tester);
    expect(find.text('El nombre solo puede tener letras y espacios'), findsOneWidget);
  });

  testWidgets('Si el backend rechaza los datos se queda en Ajustes con su mensaje', (tester) async {
    final servicio = _PerfilFalso()..errorAlGuardar = const PerfilException('El teléfono debe tener 10 dígitos');
    await _abrir(tester, servicio);
    await _abrirAjustes(tester);
    await _escribir(tester, 'ajustes_nombre', 'Ana Laura');
    await _guardar(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('El teléfono debe tener 10 dígitos'), findsOneWidget);
  });

  group('Foto de perfil', () {
    late List<ImageSource> origenes;
    XFile? elegida;

    setUp(() {
      origenes = [];
      elegida = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'mi_foto.jpg', path: 'mi_foto.jpg');
      elegirFotoPerfil = (origen) async {
        origenes.add(origen);
        return elegida;
      };
    });

    testWidgets('La cámara del avatar deja elegir galería o cámara, sube la foto y la guarda', (tester) async {
      final servicio = _PerfilFalso();
      await _abrir(tester, servicio);
      await tester.tap(find.byKey(const Key('perfil_foto')));
      await tester.pumpAndSettle();

      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Tomar foto'), findsOneWidget);
      await tester.tap(find.byKey(const Key('foto_galeria')));
      await tester.pumpAndSettle();

      expect(origenes, [ImageSource.gallery]);
      expect(servicio.fotosSubidas, ['mi_foto.jpg']);
      expect(servicio.actualizaciones.single['foto'], 'https://res.cloudinary.com/tienda/image/upload/joyeria/usuarios/mi_foto.jpg');
      expect(find.text('Tu foto se actualizó'), findsOneWidget);
    });

    testWidgets('Tomar foto usa la cámara', (tester) async {
      await _abrir(tester, _PerfilFalso());
      await tester.tap(find.byKey(const Key('perfil_foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('foto_camara')));
      await tester.pumpAndSettle();

      expect(origenes, [ImageSource.camera]);
    });

    testWidgets('Si cierra la galería sin elegir no cambia nada', (tester) async {
      elegida = null;
      final servicio = _PerfilFalso();
      await _abrir(tester, servicio);
      await tester.tap(find.byKey(const Key('perfil_foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('foto_galeria')));
      await tester.pumpAndSettle();

      expect(servicio.fotosSubidas, isEmpty);
      expect(servicio.actualizaciones, isEmpty);
      expect(find.text('Tu foto se actualizó'), findsNothing);
    });
  });
}
