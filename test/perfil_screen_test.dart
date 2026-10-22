// TIPO: widget
// ALCANCE: HU-14 · Mi perfil (#50): datos de la cuenta, números de pedidos, apartados y favoritos, accesos y estados
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/perfil_screen_test.dart
// DATOS: backend simulado en memoria (sin red); perfil y conteos de ejemplo

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/perfil.dart';
import 'package:joyeria_diana_laura/providers/tema_provider.dart';
import 'package:joyeria_diana_laura/screens/perfil_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/perfil_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// Perfil en memoria: devuelve la cuenta y los números indicados o falla como se le pida.
class _PerfilFalso extends PerfilService {
  _PerfilFalso({this.cuenta, this.numeros = const ResumenCliente(pedidos: 3, apartados: 2, favoritos: 8), this.error})
    : super(
        api: ApiClient(),
        pedidos: PedidoService(api: ApiClient()),
        favoritos: FavoritoService(api: ApiClient()),
      );

  Perfil? cuenta;
  ResumenCliente numeros;
  PerfilException? error;
  int consultas = 0;

  @override
  Future<Perfil> perfil() async {
    consultas++;
    if (error != null) throw error!;
    return cuenta!;
  }

  @override
  Future<ResumenCliente> resumen() async => numeros;
}

final _ana = Perfil.fromJson({
  'nombre': 'Ana Martínez',
  'email': 'ana.martinez@correo.com',
  'telefono': '7711234567',
  'foto_perfil_url': null,
  'fecha_creacion': '2026-10-02T15:20:00.000Z',
});

Future<void> _abrir(WidgetTester tester, PerfilService servicio, {TemaProvider? tema}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  // El tema es global (AppColors): cada prueba deja el oscuro de nuevo.
  addTearDown(() => AppColors.usar(Paleta.oscuraBoceto));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PerfilService>.value(value: servicio),
        ChangeNotifierProvider<TemaProvider>.value(value: tema ?? TemaProvider(MemoriaPreferenciaTema())),
      ],
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: const PerfilScreen(),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
          '/mis-pedidos': (_) => const Scaffold(body: Text('Pantalla de mis pedidos')),
          '/mis-apartados': (_) => const Scaffold(body: Text('Pantalla de mis apartados')),
          '/mis-personalizaciones': (_) => const Scaffold(body: Text('Pantalla de mis personalizaciones')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra el diseño del boceto con los datos de la cuenta', (tester) async {
    await _abrir(tester, _PerfilFalso(cuenta: _ana));

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('Ana Martínez'), findsOneWidget);
    expect(find.text('ana.martinez@correo.com'), findsOneWidget);
    expect(find.text('Clienta desde oct 2026'), findsOneWidget);
    expect(find.byTooltip('Ajustes'), findsOneWidget);
    expect(find.byKey(const Key('perfil_foto')), findsOneWidget);
  });

  testWidgets('Muestra cuántos pedidos, apartados y favoritos tiene', (tester) async {
    await _abrir(tester, _PerfilFalso(cuenta: _ana));
    for (final (numero, nombre) in [('3', 'Pedidos'), ('2', 'Apartados'), ('8', 'Favoritos')]) {
      expect(find.text(numero), findsOneWidget);
      expect(find.text(nombre), findsOneWidget);
    }
  });

  testWidgets('Si un número no se pudo traer muestra un guion y los demás igual', (tester) async {
    await _abrir(tester, _PerfilFalso(cuenta: _ana, numeros: const ResumenCliente(pedidos: 5, favoritos: 0)));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('Los accesos abren Mis pedidos, Mis apartados y Mis personalizaciones', (tester) async {
    await _abrir(tester, _PerfilFalso(cuenta: _ana));
    for (final (opcion, pantalla) in [
      ('Mis pedidos', 'Pantalla de mis pedidos'),
      ('Mis apartados', 'Pantalla de mis apartados'),
      ('Mis personalizaciones', 'Pantalla de mis personalizaciones'),
    ]) {
      await tester.tap(find.text(opcion));
      await tester.pumpAndSettle();
      expect(find.text(pantalla), findsOneWidget);
      Navigator.of(tester.element(find.text(pantalla))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Los ajustes, la foto y cerrar sesión están visibles y avisan que llegan pronto', (tester) async {
    await _abrir(tester, _PerfilFalso(cuenta: _ana));
    expect(find.text('Cerrar sesión'), findsOneWidget);

    for (final toque in [find.byTooltip('Ajustes'), find.byKey(const Key('perfil_foto')), find.text('Cerrar sesión')]) {
      await tester.ensureVisible(toque);
      await tester.tap(toque);
      await tester.pump();
      expect(find.text('Disponible muy pronto'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(PerfilScreen))).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Con un solo nombre usa su inicial y sin fecha no muestra Clienta desde', (tester) async {
    await _abrir(tester, _PerfilFalso(cuenta: Perfil.fromJson({'nombre': 'Valentina', 'email': 'vale@correo.com'})));
    expect(find.text('V'), findsOneWidget);
    expect(find.textContaining('Clienta desde'), findsNothing);
  });

  testWidgets('Sin sesión invita a iniciarla', (tester) async {
    await _abrir(tester, _PerfilFalso(error: const PerfilException('Inicia sesión para ver tu perfil.', sinSesion: true)));
    expect(find.text('Inicia sesión para ver tu perfil'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de login'), findsOneWidget);
  });

  testWidgets('Sin conexión deja reintentar y entonces muestra el perfil', (tester) async {
    final servicio = _PerfilFalso(cuenta: _ana, error: const PerfilException('No se pudo conectar.'));
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);

    servicio.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(servicio.consultas, 2);
    expect(find.text('Ana Martínez'), findsOneWidget);
  });

  group('Tema (#212)', () {
    testWidgets('El interruptor empieza encendido con el tema oscuro', (tester) async {
      await _abrir(tester, _PerfilFalso(cuenta: _ana));
      expect(find.text('Tema oscuro'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('perfil_tema'))).value, isTrue);
      expect(AppColors.fondo, Paleta.oscuraBoceto.fondo);
    });

    testWidgets('Al apagarlo cambia a la paleta clara del boceto y guarda la preferencia', (tester) async {
      final preferencia = MemoriaPreferenciaTema();
      final tema = TemaProvider(preferencia);
      await _abrir(tester, _PerfilFalso(cuenta: _ana), tema: tema);
      await tester.ensureVisible(find.byKey(const Key('perfil_tema')));
      await tester.tap(find.byKey(const Key('perfil_tema')));
      await tester.pumpAndSettle();

      expect(tema.oscuro, isFalse);
      expect(tester.widget<Switch>(find.byKey(const Key('perfil_tema'))).value, isFalse);
      expect(AppColors.fondo, const Color(0xFFFFF6FA));
      expect(AppColors.primario, const Color(0xFFC9668F));
      expect(await preferencia.leerOscuro(), isFalse);
    });

    testWidgets('Tocar el renglón también cambia el tema y se puede regresar al oscuro', (tester) async {
      final tema = TemaProvider(MemoriaPreferenciaTema());
      await _abrir(tester, _PerfilFalso(cuenta: _ana), tema: tema);
      await tester.ensureVisible(find.text('Tema oscuro'));
      await tester.tap(find.text('Tema oscuro'));
      await tester.pumpAndSettle();
      expect(tema.oscuro, isFalse);

      await tester.tap(find.text('Tema oscuro'));
      await tester.pumpAndSettle();
      expect(tema.oscuro, isTrue);
      expect(AppColors.fondo, Paleta.oscuraBoceto.fondo);
    });

    test('Al abrir la app usa la preferencia guardada y, si no hay, el oscuro', () async {
      expect(await TemaProvider.leerInicial(MemoriaPreferenciaTema()), isTrue);
      expect(await TemaProvider.leerInicial(MemoriaPreferenciaTema(false)), isFalse);
      expect(await TemaProvider.leerInicial(_PreferenciaRota()), isTrue);
      TemaProvider(MemoriaPreferenciaTema(), oscuro: false);
      expect(AppColors.fondo, Paleta.claraBoceto.fondo);
      AppColors.usar(Paleta.oscuraBoceto);
    });
  });
}

// Teléfono que no deja leer la preferencia.
class _PreferenciaRota implements PreferenciaTema {
  @override
  Future<bool?> leerOscuro() => Future.error(Exception('sin acceso'));

  @override
  Future<void> guardarOscuro(bool oscuro) async {}
}
