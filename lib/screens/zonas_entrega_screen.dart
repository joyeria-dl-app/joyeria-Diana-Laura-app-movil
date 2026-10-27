import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/zona_entrega.dart';
import '../services/zonas_service.dart';
import '../theme/app_theme.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';
import '../widgets/tarjeta_info.dart';

// Abre WhatsApp o el mapa; las pruebas lo reemplazan para no salir de la app.
Future<bool> Function(Uri) abrirEnlaceZonas = (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

// Zonas de entrega (HU-16, #59): boceto 16 de Bocetos_Sprint4. Lo mismo que "Entregas a domicilio"
// de Nuestra ubicación en el sitio web: zonas activas, envío por terceros, la tienda para recoger
// y "Preguntar por mi zona" por WhatsApp.
class ZonasEntregaScreen extends StatefulWidget {
  const ZonasEntregaScreen({super.key});

  @override
  State<ZonasEntregaScreen> createState() => _ZonasEntregaScreenState();
}

class _ZonasEntregaScreenState extends State<ZonasEntregaScreen> {
  late Future<InfoEntregas> _info = context.read<ZonasService>().entregas();

  void _recargar() {
    final nueva = context.read<ZonasService>().entregas();
    setState(() {
      _info = nueva;
    });
  }

  Future<void> _abrir(Uri enlace) async {
    if (await abrirEnlaceZonas(enlace) || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
          SafeArea(
            child: FutureBuilder<InfoEntregas>(
              future: _info,
              builder: (context, estado) {
                final cargando = estado.connectionState != ConnectionState.done;
                final info = estado.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context))],
                      ),
                    ),
                    Expanded(
                      child: cargando
                          ? Center(child: CircularProgressIndicator(color: AppColors.primario))
                          : info == null
                          // 16c.
                          ? AvisoVacio(
                              icono: Icons.wifi_off_rounded,
                              titulo: 'Sin conexión',
                              texto: 'No se pudieron cargar las zonas de entrega. Revisa tu conexión e intenta de nuevo.',
                              boton: 'Reintentar',
                              iconoBoton: Icons.refresh_rounded,
                              onPressed: _recargar,
                            )
                          : _Contenido(info: info, onAbrir: _abrir),
                    ),
                    if (info?.preguntarPorMiZona != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: BotonDegradado(
                          key: const Key('zonas_preguntar'),
                          texto: 'Preguntar por mi zona',
                          icono: Icons.chat_outlined,
                          ancho: true,
                          onPressed: () => _abrir(info!.preguntarPorMiZona!),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.info, required this.onAbrir});
  final InfoEntregas info;
  final void Function(Uri) onAbrir;

  @override
  Widget build(BuildContext context) {
    final zonas = info.zonas;
    final direccion = info.direccion;
    final horario = info.horario;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      children: [
        // 16a.
        const Antetitulo('Entregas a domicilio'),
        const SizedBox(height: 2),
        const TituloDegradado('Zonas de entrega', tamano: 28),
        const SizedBox(height: 6),
        Text(
          'Llevamos tus piezas a estas zonas. Si la tuya no aparece, pregúntanos.',
          style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (zonas == null)
          const TarjetaInfo(icono: Icons.wifi_off_rounded, titulo: 'No se pudieron cargar las zonas', texto: 'Vuelve a abrir esta pantalla en un momento.')
        else if (zonas.isEmpty)
          const TarjetaInfo(
            icono: Icons.location_off_outlined,
            titulo: 'Por ahora no hay zonas de entrega',
            texto: 'Puedes recoger tu pedido en la tienda o preguntarnos por tu zona.',
          )
        else
          _ListaZonas(zonas: zonas, direccionTienda: direccion),
        const SizedBox(height: 12),
        const TarjetaInfo(
          icono: Icons.local_shipping_outlined,
          titulo: 'Envío por terceros',
          texto: 'Transportistas locales, combis y similares. El costo se ve al confirmar tu pedido.',
        ),
        // 16b.
        if (direccion != null || horario != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4, 18, 0, 8),
            child: Text(
              'También puedes recoger en tienda',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (direccion != null) TarjetaInfo(icono: Icons.storefront_outlined, titulo: 'Joyería Diana Laura', texto: direccion),
          if (direccion != null && horario != null) const SizedBox(height: 10),
          if (horario != null) TarjetaInfo(icono: Icons.schedule_rounded, titulo: 'Horario', texto: horario),
          if (direccion != null) ...[
            const SizedBox(height: 12),
            _Chip(
              icono: Icons.directions_outlined,
              texto: 'Cómo llegar',
              onTap: () => onAbrir(Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': direccion})),
            ),
          ],
        ],
      ],
    );
  }
}

class _ListaZonas extends StatelessWidget {
  const _ListaZonas({required this.zonas, this.direccionTienda});
  final List<ZonaEntrega> zonas;
  final String? direccionTienda;

  @override
  Widget build(BuildContext context) {
    // La zona donde está la tienda (por ejemplo Huejutla en "…, Huejutla de Reyes, Hidalgo").
    final tienda = direccionTienda?.toLowerCase() ?? '';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          for (var i = 0; i < zonas.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.borde),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(15)),
                    child: Icon(Icons.location_on_rounded, size: 20, color: AppColors.primario),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(zonas[i].nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  if (tienda.contains(zonas[i].nombre.toLowerCase())) const Etiqueta('Aquí está la tienda'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Botón de contorno de los bocetos (.chip).
class _Chip extends StatelessWidget {
  const _Chip({required this.icono, required this.texto, required this.onTap});
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: AppColors.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 19, color: AppColors.texto),
              const SizedBox(width: 6),
              Text(texto, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
