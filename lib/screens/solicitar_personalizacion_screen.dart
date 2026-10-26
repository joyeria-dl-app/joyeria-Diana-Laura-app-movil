import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../routes/app_routes.dart';
import '../services/personalizacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';

// Abre la galería o la cámara para la foto de referencia. Las pruebas lo cambian para no abrir nada.
Future<XFile?> Function(ImageSource) elegirFotoReferencia = (origen) => ImagePicker().pickImage(source: origen, imageQuality: 85, maxWidth: 1800);

// HU-13 (#46): el cliente describe qué quiere cambiar de la pieza y, si quiere, agrega una foto de
// referencia. La solicitud llega a la pantalla de personalizaciones del trabajador en el sitio web.
class SolicitarPersonalizacionScreen extends StatefulWidget {
  const SolicitarPersonalizacionScreen({super.key, required this.producto, this.foto, this.precioPersonalizacion = 0});

  final Producto producto;
  final String? foto;
  final double precioPersonalizacion;

  @override
  State<SolicitarPersonalizacionScreen> createState() => _SolicitarPersonalizacionScreenState();
}

class _SolicitarPersonalizacionScreenState extends State<SolicitarPersonalizacionScreen> {
  final _detalle = TextEditingController();
  ({Uint8List bytes, String nombre})? _referencia;
  bool _enviando = false;
  String? _error;
  // Días que tarda la revisión; se llena al enviar.
  int? _enviadaEnDias;

  @override
  void initState() {
    super.initState();
    _detalle.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  int get _caracteres => _detalle.text.trim().length;
  bool get _detalleValido => _caracteres >= PersonalizacionService.minimoDetalle && _caracteres <= PersonalizacionService.maximoDetalle;

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primario),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primario),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (origen == null) return;
    final foto = await elegirFotoReferencia(origen);
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (mounted) setState(() => _referencia = (bytes: bytes, nombre: foto.name.isEmpty ? 'referencia.jpg' : foto.name));
  }

  Future<void> _enviar() async {
    if (!_detalleValido || _enviando) return;
    FocusScope.of(context).unfocus();
    final servicio = context.read<PersonalizacionService>();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final referencia = _referencia;
      final url = referencia == null ? null : await servicio.subirReferencia(referencia.bytes, referencia.nombre);
      final enviada = await servicio.solicitar(productoId: widget.producto.id, detalle: _detalle.text, imagenReferencia: url);
      if (mounted) setState(() => _enviadaEnDias = enviada.diasEstimados);
    } on PersonalizacionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
      if (e.sinSesion) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Inicia sesión para solicitar una personalización'),
              action: SnackBarAction(label: 'Iniciar sesión', onPressed: () => Navigator.pushNamed(context, AppRoutes.login)),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context)),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 44),
                          child: Text(
                            'Personalizar pieza',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _enviadaEnDias == null ? _formulario() : _enviada(_enviadaEnDias!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    final p = widget.producto;
    final referencia = _referencia;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        // La pieza que se va a personalizar.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borde),
          ),
          child: Row(
            children: [
              FotoPieza(url: widget.foto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.precioPersonalizacion > 0
                          ? '${formatoPrecioCompleto(p.precioFinal)} · personalizar +${formatoPrecioCompleto(widget.precioPersonalizacion)}'
                          : formatoPrecioCompleto(p.precioFinal),
                      style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Antetitulo('¿Qué quieres cambiar?'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('personalizacion_detalle'),
          controller: _detalle,
          minLines: 4,
          maxLines: 7,
          maxLength: PersonalizacionService.maximoDetalle,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Por ejemplo: grabar las iniciales D & L por dentro, en letra cursiva.', counterText: ''),
        ),
        const SizedBox(height: 6),
        Text(
          _caracteres < PersonalizacionService.minimoDetalle
              ? 'Escribe al menos ${PersonalizacionService.minimoDetalle} caracteres ($_caracteres/${PersonalizacionService.minimoDetalle}).'
              : '$_caracteres/${PersonalizacionService.maximoDetalle}',
          style: const TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
        ),
        const SizedBox(height: 20),
        const Antetitulo('Foto de referencia (opcional)'),
        const SizedBox(height: 8),
        if (referencia == null)
          Semantics(
            button: true,
            label: 'Agregar foto de referencia',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _enviando ? null : _elegirFoto,
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borde, width: 1.5),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: AppColors.primario, size: 28),
                    SizedBox(height: 6),
                    Text('Agregar foto', style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.memory(referencia.bytes, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: BotonCristal(icono: Icons.close_rounded, descripcion: 'Quitar foto', onPressed: () => setState(() => _referencia = null)),
              ),
            ],
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(18)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primario),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La tienda revisa tu solicitud y te avisa por correo. Si la aprueba, podrás comprar la pieza personalizada.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: const TextStyle(color: Color(0xFFE5677A), fontSize: 12.5))],
        const SizedBox(height: 22),
        Opacity(
          opacity: _detalleValido ? 1 : 0.5,
          child: BotonDegradado(
            texto: _enviando ? 'Enviando…' : 'Enviar solicitud',
            icono: _enviando ? null : Icons.send_rounded,
            ancho: true,
            onPressed: _detalleValido && !_enviando ? _enviar : null,
          ),
        ),
      ],
    );
  }

  Widget _enviada(int dias) => AvisoVacio(
    icono: Icons.check_rounded,
    titulo: '¡Solicitud enviada!',
    texto:
        'Recibimos tu solicitud para ${widget.producto.nombre}. La tienda la revisará en $dias ${dias == 1 ? 'día hábil' : 'días hábiles'} y te avisará por correo.',
    boton: 'Volver a la pieza',
    iconoBoton: Icons.diamond_rounded,
    onPressed: () => Navigator.pop(context, true),
  );
}
