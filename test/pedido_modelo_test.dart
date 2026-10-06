import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/utils/fechas.dart';
import 'package:joyeria_diana_laura/widgets/estado_pedido.dart';

// HU-11 · Reglas de los pedidos y apartados que la app calcula por su cuenta.

Apartado _apartado({String estado = 'activo', double total = 1000, double pagado = 500, double? plan, bool porConfirmar = false}) => Apartado(
  id: 7,
  folio: 'AP-1',
  estado: estado,
  montoTotal: total,
  montoPagado: pagado,
  saldo: total - pagado,
  planPorcentaje: plan,
  abonoPorConfirmar: porConfirmar,
);

void main() {
  group('Abono sugerido', () {
    test('Es la cuota del plan sobre el total', () {
      expect(_apartado(plan: 25).abonoSugerido, 250);
    });

    test('No pasa del saldo', () {
      expect(_apartado(pagado: 900, plan: 25).abonoSugerido, 100);
    });

    test('Sin plan sugiere liquidar el saldo', () {
      expect(_apartado().abonoSugerido, 500);
    });
  });

  group('Cuándo se puede abonar', () {
    test('Activo y con saldo', () => expect(_apartado().puedeAbonar, isTrue));
    test('No con el pago inicial sin confirmar', () => expect(_apartado(estado: 'pendiente_pago').puedeAbonar, isFalse));
    test('No con otro abono por confirmar', () => expect(_apartado(porConfirmar: true).puedeAbonar, isFalse));
    test('No si ya está liquidado', () => expect(_apartado(estado: 'liquidado', pagado: 1000).puedeAbonar, isFalse));
  });

  test('El avance del apartado va de 0 a 1', () {
    expect(_apartado().avance, .5);
    expect(_apartado(total: 0, pagado: 0).avance, 0);
  });

  test('Lee el plan y el abono por confirmar del backend', () {
    final a = Apartado.fromJson({
      'id': 7,
      'estado': 'activo',
      'monto_total': '1000',
      'monto_pagado': '500',
      'saldo_pendiente': '500',
      'plan_porcentaje': '25',
      'abono_pendiente': {'id': 3},
    });
    expect(a.planPorcentaje, 25);
    expect(a.abonoPorConfirmar, isTrue);
    expect(a.puedeAbonar, isFalse);
  });

  group('Estado del pedido', () {
    test('Transferencia sin comprobante espera que el cliente lo suba', () {
      const p = Pedido(id: 1, folio: 'DL-1', estado: 'pendiente', total: 10, metodoPagoCodigo: 'transferencia');
      expect(p.esperaComprobante, isTrue);
      const conComprobante = Pedido(id: 1, folio: 'DL-1', estado: 'pendiente', total: 10, metodoPagoCodigo: 'transferencia', comprobanteUrl: 'https://x/c.jpg');
      expect(conComprobante.esperaComprobante, isFalse);
    });

    test('Cancelado y expirado cuentan como terminados', () {
      for (final estado in ['cancelado', 'expirado']) {
        final p = Pedido(id: 1, folio: 'DL-1', estado: estado, total: 10);
        expect(p.cancelado, isTrue);
        expect(p.enCurso, isFalse);
      }
    });

    test('Usa la fecha del último cambio a ese estado', () {
      final p = Pedido(
        id: 1,
        folio: 'DL-1',
        estado: 'confirmado',
        total: 10,
        historial: [
          CambioEstado(estado: 'confirmado', fecha: DateTime(2026, 10, 5)),
          CambioEstado(estado: 'confirmado', fecha: DateTime(2026, 10, 6)),
        ],
      );
      expect(p.fechaDe('confirmado'), DateTime(2026, 10, 6));
    });
  });

  group('Línea de tiempo', () {
    test('A domicilio tiene el paso Enviado; en tienda termina en Recogido en tienda', () {
      const domicilio = Pedido(id: 1, folio: 'DL-1', estado: 'enviado', total: 10, domicilio: true);
      const tienda = Pedido(id: 2, folio: 'DL-2', estado: 'confirmado', total: 10);
      expect(pasosDe(domicilio).map((p) => p.titulo), ['Pedido recibido', 'Confirmado', 'En preparación', 'Enviado', 'Entregado']);
      expect(pasosDe(tienda).map((p) => p.titulo).last, 'Recogido en tienda');
      expect(pasosDe(tienda).map((p) => p.titulo), isNot(contains('Enviado')));
    });

    test('Marca hechos los pasos anteriores y como actual el estado del pedido', () {
      const p = Pedido(id: 1, folio: 'DL-1', estado: 'en_preparacion', total: 10);
      final pasos = pasosDe(p);
      expect(pasos.map((s) => s.hecho), [true, true, false, false]);
      expect(pasos.indexWhere((s) => s.actual), 2);
    });

    test('Entregado deja todos los pasos hechos', () {
      const p = Pedido(id: 1, folio: 'DL-1', estado: 'entregado', total: 10);
      expect(pasosDe(p).every((s) => s.hecho && !s.actual), isTrue);
    });

    test('Cancelado muestra hasta donde llegó y termina en Cancelado', () {
      final p = Pedido(
        id: 1,
        folio: 'DL-1',
        estado: 'cancelado',
        total: 10,
        fechaCreacion: DateTime(2026, 10, 5),
        historial: [
          CambioEstado(estado: 'confirmado', fecha: DateTime(2026, 10, 5, 12)),
          CambioEstado(estado: 'cancelado', fecha: DateTime(2026, 10, 6)),
        ],
      );
      expect(pasosDe(p).map((s) => s.titulo), ['Pedido recibido', 'Confirmado', 'Cancelado']);
      expect(pasosDe(p).last.actual, isTrue);
    });
  });

  group('Fechas', () {
    final f = DateTime(2026, 10, 8, 9, 5);

    test('Corta, con hora y larga en español', () {
      expect(fechaCorta(f), '8 oct');
      expect(fechaHora(f), '8 oct · 09:05');
      expect(fechaLarga(f), 'jueves 8 de octubre');
      expect(fechaLarga(f, corta: true), 'jueves 8');
    });

    test('Días que faltan: 0 si es hoy o ya pasó', () {
      final hoy = DateTime(2026, 10, 6, 23);
      expect(diasHasta(f, hoy: hoy), 2);
      expect(diasHasta(DateTime(2026, 10, 6, 1), hoy: hoy), 0);
      expect(diasHasta(DateTime(2026, 10, 1), hoy: hoy), 0);
    });
  });
}
