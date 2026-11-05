// TIPO: integración
// ALCANCE: HU-03 a HU-16 · casos I-01 a I-07: la app completa en un recorrido (Sprint 4, #151)
// EJECUCIÓN: A MANO, en el emulador: la tienda confirma el pedido con un script. flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/integracion_app_test.dart --dart-define-from-file=env.json
// DATOS: integration_test/datos_prueba.dart (cuenta de env.json o de los secretos); un pedido real en efectivo que se cancela al terminar

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/avisos_pedido.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/notificaciones_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';
import 'datos_prueba.dart';

// Prueba de integración del Sprint 4 (#151): un solo recorrido por la app completa en el
// emulador contra el backend real, con el build de perfil (compilado AOT como el de producción).
// En cada paso se compara lo que muestra la app con lo que registra el servidor. Resultados en
// pruebas/integracion_sprint4.md.
//
// La prueba avisa con "INTEGRACION PASO" lo que hace la tienda:
//   confirmar <folio>   la tienda confirma el pedido y el servidor manda la notificación push
//   limpiar <folio>     cancelar el pedido de prueba
// No corre en los pipelines: necesita a la tienda. El pago con Mercado Pago ya se probó en la
// integración del Sprint 3 (#146); aquí el pedido se paga en efectivo en tienda.

// Deja la pantalla quieta unos segundos para la captura de evidencia con adb.
Future<void> _caso(WidgetTester tester, String id, String descripcion) async {
  debugPrint('INTEGRACION $id Pasa: $descripcion');
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  }
}

void _paso(String paso) => debugPrint('INTEGRACION PASO $paso');

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

// "5+ piezas", "10+ piezas"… o "17 piezas" cuando ya llegaron todas (#269).
int _piezasEnPantalla(WidgetTester tester) {
  final texto = tester.widget<Text>(find.textContaining(RegExp(r'^\d+\+? piezas$'))).data!;
  return int.parse(RegExp(r'^\d+').firstMatch(texto)!.group(0)!);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Integración Sprint 4: la app completa de la sesión al perfil', (tester) async {
    expect(CuentaPrueba.correo, isNotEmpty, reason: 'Falta el correo de la cuenta de prueba (env.json)');
    expect(CuentaPrueba.contrasena, isNotEmpty, reason: 'Falta la contraseña de la cuenta de prueba (env.json)');

    // I-01 (HU-03 y #244): inicia sesión y el Inicio saluda a la cuenta. Con Firebase y los avisos
    // del pedido como en main.dart, para que el emulador quede registrado y reciba el push (I-05).
    await Firebase.initializeApp();
    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage(), mensajeria: FirebaseMensajeria()));
    await AvisosPedido(fuente: FirebaseFuenteAvisos(), abrirPedido: abrirPedidoDesdeAviso).iniciar();
    await iniciarSesion(tester, CuentaPrueba.correo, CuentaPrueba.contrasena);
    await esperar(tester, find.byKey(const Key('inicio_carrusel')));
    final saludo = tester.widget<Text>(find.descendant(of: find.byKey(inicioConSesion), matching: find.byType(Text)).first).data!;
    await _caso(tester, 'I-01', 'inició sesión y el Inicio saluda: "$saludo"');

    final contexto = tester.element(find.byType(Scaffold).first);
    final pedidos = contexto.read<PedidoService>();
    final carritoServidor = contexto.read<CarritoService>();
    final carrito = contexto.read<CarritoProvider>();

    Future<T> esperarServidor<T>(Future<T?> Function() leer, String que, {int minutos = 15}) async {
      final fin = DateTime.now().add(Duration(minutes: minutos));
      while (DateTime.now().isBefore(fin)) {
        final valor = await tester.runAsync(leer);
        if (valor != null) return valor;
        await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 5)));
        await tester.pump();
      }
      fail('El servidor no registró: $que');
    }

    Future<Pedido?> pedido(String folio, bool Function(Pedido) cumple) async =>
        (await pedidos.misPedidos()).where((p) => p.folio == folio && cumple(p)).firstOrNull;

    // I-02 (HU-05 y #269): el chip de Anillos abre la categoría de 5 en 5; al bajar llegan más.
    final chip = find.text(PiezasPrueba.categoriaCompra).first;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await esperar(tester, find.textContaining(RegExp(r'^\d+\+? piezas$')));
    final primeras = _piezasEnPantalla(tester);
    expect(primeras, ProductoService.porPagina);
    for (var i = 0; i < 6 && _piezasEnPantalla(tester) == primeras; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pumpAndSettle();
    }
    final despues = _piezasEnPantalla(tester);
    expect(despues, greaterThan(primeras));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await _caso(tester, 'I-02', '${PiezasPrueba.categoriaCompra} abrió con $primeras piezas y al bajar llegó a $despues');

    // I-03 (HU-06 y HU-09): la pieza más barata con existencia llega al carrito con su precio.
    final pieza = (await tester.runAsync(() async {
      final productos = contexto.read<ProductoService>();
      final categoria = (await productos.categorias()).firstWhere((c) => c.nombre == PiezasPrueba.categoriaCompra);
      final lista = <dynamic>[];
      for (var pagina = 0; ; pagina++) {
        final parte = await productos.productos(categoriaId: categoria.id, pagina: pagina);
        lista.addAll(parte);
        if (parte.length < ProductoService.porPagina) break;
      }
      final disponibles = lista.where((p) => p.stock >= 2).toList()..sort((a, b) => a.precioFinal.compareTo(b.precioFinal));
      return disponibles.first;
    }))!;
    await tester.runAsync(() async {
      await carritoServidor.vaciar();
      await carritoServidor.agregar(pieza.id);
      await carrito.cargar();
    });
    _navegador(tester).pushNamed(AppRoutes.carrito);
    await esperar(tester, find.text('Ir a pagar'));
    expect(find.text(pieza.nombre), findsWidgets);
    await _caso(tester, 'I-03', 'el carrito tiene ${pieza.nombre} de ${formatoPrecioCompleto(pieza.precioFinal)}, igual que en el servidor');

    // I-04 (HU-11 y HU-16): pedido en tienda pagando en efectivo; el servidor lo registra pendiente.
    await tester.tap(find.text('Ir a pagar'));
    await esperar(tester, find.text('Efectivo en tienda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En tienda'));
    await tester.pump();
    await tester.ensureVisible(find.text('Efectivo en tienda'));
    await tester.tap(find.text('Efectivo en tienda'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await esperar(tester, find.text('¡Pedido enviado!'));
    final folio = (tester.widget<Text>(find.textContaining(RegExp(r'^Pedido DL-'))).data!).replaceFirst('Pedido ', '');
    final creado = await esperarServidor(() => pedido(folio, (p) => p.estado == 'pendiente'), 'el pedido $folio', minutos: 1);
    expect(creado.total, closeTo(pieza.precioFinal, 0.01));
    await _caso(tester, 'I-04', 'el pedido $folio de ${formatoPrecioCompleto(creado.total)} en efectivo quedó pendiente en el servidor');

    // I-05 (HU-15): la tienda lo confirma y el servidor manda la notificación push al teléfono.
    // La notificación del sistema se revisa desde la computadora con adb (dumpsys notification).
    _paso('confirmar $folio');
    await esperarServidor(() => pedido(folio, (p) => p.estado == 'confirmado'), 'el pedido $folio confirmado');
    await _caso(tester, 'I-05', 'la tienda confirmó $folio y el servidor lo registra confirmado');

    // I-06 (HU-14): Mi perfil → Mis pedidos muestra el pedido confirmado y su seguimiento.
    await tester.tap(find.text('Ver mis pedidos'));
    await esperar(tester, find.text('Pedido $folio'));
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    await tester.pumpAndSettle();
    _navegador(tester).pushNamed(AppRoutes.perfil);
    await esperar(tester, find.text('Mis pedidos'));
    await tester.tap(find.text('Mis pedidos'));
    await esperar(tester, find.text('Pedido $folio'));
    await tester.tap(find.text('Pedido $folio'));
    await esperar(tester, find.byType(SeguimientoScreen));
    await tester.pumpAndSettle();
    await _caso(tester, 'I-06', 'Mi perfil → Mis pedidos muestra $folio y su seguimiento confirmado');

    // I-07 (HU-16): desde Mi perfil se consultan las zonas de entrega del servidor.
    _navegador(tester).pop();
    _navegador(tester).pop();
    await tester.pumpAndSettle();
    await esperar(tester, find.text('Zonas de entrega'));
    await tester.ensureVisible(find.text('Zonas de entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zonas de entrega'));
    await esperar(tester, find.byKey(const Key('zonas_preguntar')));
    await _caso(tester, 'I-07', 'Mi perfil abre las zonas de entrega del servidor');

    _paso('limpiar $folio');
  });
}
