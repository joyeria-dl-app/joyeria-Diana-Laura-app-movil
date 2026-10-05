import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/pasos_pedido.dart';

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

// Lo que se muestra al terminar: pedido (8e) o apartado (8f).
class PedidoListo {
  const PedidoListo._({required this.apartado, required this.folio, required this.renglones});

  factory PedidoListo.compra({required String folio, required int piezas, required bool domicilio, required String metodo, required double total}) =>
      PedidoListo._(
        apartado: false,
        folio: folio,
        renglones: [
          ('Piezas', '$piezas'),
          ('Entrega', domicilio ? 'A domicilio' : 'En tienda'),
          ('Pago', metodo == 'Efectivo en Tienda' ? 'Efectivo en tienda' : metodo),
          ('Total', formatoPrecioCompleto(total)),
        ],
      );

  factory PedidoListo.apartado({required String folio, required double abonoHoy, required double saldo, String? plan, DateTime? fechaLimite}) => PedidoListo._(
    apartado: true,
    folio: folio,
    renglones: [
      ('Abono de hoy', formatoPrecioCompleto(abonoHoy)),
      ('Queda por pagar', formatoPrecioCompleto(saldo < 0 ? 0 : saldo)),
      if (plan != null) ('Plan', plan),
      if (fechaLimite != null) ('Fecha límite', '${fechaLimite.day} ${_meses[fechaLimite.month - 1]}'),
    ],
  );

  final bool apartado;
  final String folio;
  final List<(String, String)> renglones;
}

// Paso 3: pedido enviado (8e) o piezas apartadas (8f).
class PedidoListoScreen extends StatelessWidget {
  const PedidoListoScreen({super.key, required this.listo});
  final PedidoListo listo;

  @override
  Widget build(BuildContext context) {
    final apartado = listo.apartado;
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const PasosPedido(actual: 3),
                const SizedBox(height: 30),
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primario, AppColors.primario2]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Color(0x80CF819F), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
                    ),
                    child: Icon(apartado ? Icons.bookmark_added_outlined : Icons.check_rounded, size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  apartado ? '¡Piezas apartadas!' : '¡Pedido enviado!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  apartado
                      ? 'Quedan reservadas para ti. Liquida antes de la fecha límite para recogerlas en tienda.'
                      : 'Un trabajador lo revisará y te avisaremos cuando esté confirmado.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _Resumen(listo: listo),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.degradado, borderRadius: BorderRadius.circular(18)),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      // Mis pedidos y Mis apartados llegan con la tarea #38.
                      onTap: () => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(content: Text('Disponible muy pronto'))),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(apartado ? Icons.bookmark_border_rounded : Icons.receipt_long_outlined, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              apartado ? 'Ver mis apartados' : 'Ver mis pedidos',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.catalogo, (r) => r.isFirst),
                  child: const Text('Seguir comprando'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.listo});
  final PedidoListo listo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${listo.apartado ? 'Apartado' : 'Pedido'} ${listo.folio}', style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x26F6A723), borderRadius: BorderRadius.circular(20)),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(color: Color(0xFFF6A723), fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (nombre, valor) in listo.renglones)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(nombre, style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                  Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
