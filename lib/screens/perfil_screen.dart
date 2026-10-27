import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/perfil.dart';
import '../providers/tema_provider.dart';
import '../routes/app_routes.dart';
import '../services/perfil_service.dart';
import '../theme/app_theme.dart';
import '../utils/cerrar_sesion.dart';
import '../utils/fechas.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/estado_pedido.dart';
import 'ajustes_perfil_screen.dart';

// Abre la galería o la cámara para la foto de perfil. Las pruebas lo cambian para no abrir nada.
Future<XFile?> Function(ImageSource) elegirFotoPerfil = (origen) => ImagePicker().pickImage(source: origen, imageQuality: 85, maxWidth: 1080);

// Mi perfil (HU-14, #50): boceto 10 "Perfil (P15)" de A3 Interfaces con los datos reales
// de la cuenta. Del boceto, "Clienta frecuente" se muestra como "Clienta desde" (el segmento
// no se guarda por cliente) y se agrega Mis personalizaciones (HU-13). El interruptor cambia
// entre tema oscuro y claro (#212), el engrane abre Ajustes y la cámara cambia la foto (#213), y
// cerrar sesión ya funciona (#52).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Future<(Perfil, ResumenCliente)> _datos;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<(Perfil, ResumenCliente)> _cargar() async {
    final servicio = context.read<PerfilService>();
    final r = await Future.wait<Object>([servicio.perfil(), servicio.resumen()]);
    return (r[0] as Perfil, r[1] as ResumenCliente);
  }

  void _recargar() {
    final nuevos = _cargar();
    setState(() {
      _datos = nuevos;
    });
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _abrirAjustes(Perfil perfil) async {
    final guardado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AjustesPerfilScreen(perfil: perfil)));
    if (guardado != true || !mounted) return;
    _recargar();
    _aviso('Tus datos se guardaron');
  }

  // Galería o cámara; la foto se sube como en el sitio web y se guarda con PUT /auth/profile.
  Future<void> _cambiarFoto() async {
    if (_subiendoFoto) return;
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.fondo,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => const _ElegirOrigen(),
    );
    if (origen == null || !mounted) return;
    final foto = await elegirFotoPerfil(origen);
    if (foto == null || !mounted) return;
    setState(() => _subiendoFoto = true);
    final servicio = context.read<PerfilService>();
    try {
      final url = await servicio.subirFoto(await foto.readAsBytes(), foto.name);
      await servicio.actualizar(fotoUrl: url);
      if (!mounted) return;
      _recargar();
      _aviso('Tu foto se actualizó');
    } on PerfilException catch (e) {
      if (mounted) _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Foto o degradado detrás de la barra de estado: íconos blancos en los dos temas.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            FutureBuilder<(Perfil, ResumenCliente)>(
              future: _datos,
              builder: (context, estado) {
                if (estado.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(color: AppColors.primario));
                final error = estado.error;
                if (error is PerfilException && error.sinSesion) {
                  return AvisoVacio(
                    icono: Icons.lock_outline_rounded,
                    titulo: 'Inicia sesión para ver tu perfil',
                    texto: 'Con tu cuenta ves tus datos, tus pedidos y tus apartados.',
                    boton: 'Iniciar sesión',
                    iconoBoton: Icons.login_rounded,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                  );
                }
                if (error != null) {
                  return AvisoVacio(
                    icono: Icons.wifi_off_rounded,
                    titulo: 'Sin conexión',
                    texto: 'No se pudo cargar tu perfil. Revisa tu conexión e intenta de nuevo.',
                    boton: 'Reintentar',
                    iconoBoton: Icons.refresh_rounded,
                    onPressed: _recargar,
                  );
                }
                final (perfil, resumen) = estado.data!;
                return RefreshIndicator(
                  color: AppColors.primario,
                  onRefresh: () async => _recargar(),
                  child: _Contenido(
                    perfil: perfil,
                    resumen: resumen,
                    subiendoFoto: _subiendoFoto,
                    onAjustes: () => _abrirAjustes(perfil),
                    onFoto: _cambiarFoto,
                  ),
                );
              },
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(top: false, child: BarraNavegacion(actual: Seccion.perfil)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.perfil, required this.resumen, required this.subiendoFoto, required this.onAjustes, required this.onFoto});

  final Perfil perfil;
  final ResumenCliente resumen;
  final bool subiendoFoto;
  final VoidCallback onAjustes;
  final VoidCallback onFoto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const _Encabezado(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Mi perfil',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        _BotonClaro(icono: Icons.settings_outlined, descripcion: 'Ajustes', onPressed: onAjustes),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Identidad(perfil: perfil, subiendoFoto: subiendoFoto, onFoto: onFoto),
                    const SizedBox(height: 22),
                    _Numeros(resumen: resumen),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 120), child: const _Opciones()),
      ],
    );
  }
}

// Fondo del encabezado: degradado rosa a lila con dos círculos, esquinas inferiores redondas.
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250 + MediaQuery.paddingOf(context).top,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        gradient: LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: [AppColors.primario, AppColors.primario2, AppColors.lila],
          stops: [0, 0.45, 1],
        ),
      ),
      child: const Stack(
        children: [
          Positioned(top: -60, right: -50, child: _Circulo(tamano: 200, opacidad: 0.12)),
          Positioned(bottom: -30, left: 20, child: _Circulo(tamano: 120, opacidad: 0.08)),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.tamano, required this.opacidad});
  final double tamano;
  final double opacidad;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacidad),
    ),
  );
}

// Botón de vidrio blanco sobre el degradado (.gbtn con fondo blanco al 20 %).
class _BotonClaro extends StatelessWidget {
  const _BotonClaro({required this.icono, required this.descripcion, required this.onPressed});
  final IconData icono;
  final String descripcion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: descripcion,
    child: Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(width: 44, height: 44, child: Icon(icono, size: 20, color: Colors.white)),
      ),
    ),
  );
}

class _Identidad extends StatelessWidget {
  const _Identidad({required this.perfil, required this.subiendoFoto, required this.onFoto});
  final Perfil perfil;
  final bool subiendoFoto;
  final VoidCallback onFoto;

  @override
  Widget build(BuildContext context) {
    final desde = perfil.fechaRegistro;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Cambiar foto de perfil',
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('perfil_foto'),
            onTap: onFoto,
            child: SizedBox(
              width: 78,
              height: 78,
              child: Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: perfil.fotoUrl == null
                        ? Text(
                            perfil.iniciales,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                          )
                        : Image.network(
                            perfil.fotoUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            // Mientras descarga la foto se ven las iniciales.
                            loadingBuilder: (_, foto, progreso) => progreso == null
                                ? foto
                                : Center(
                                    child: Text(
                                      perfil.iniciales,
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                            errorBuilder: (_, _, _) => Text(
                              perfil.iniciales,
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                  // Mientras se sube la foto nueva, un velo con el indicador sobre el avatar.
                  if (subiendoFoto)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(26)),
                      alignment: Alignment.center,
                      child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.photo_camera_rounded, size: 14, color: Color(0xFFC94B83)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                perfil.nombre.isEmpty ? 'Clienta' : perfil.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
              Text(
                perfil.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
              if (desde != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Clienta desde ${mesAnio(desde)}',
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Tarjeta de vidrio con Pedidos · Apartados · Favoritos.
class _Numeros extends StatelessWidget {
  const _Numeros({required this.resumen});
  final ResumenCliente resumen;

  @override
  Widget build(BuildContext context) {
    Widget numero(int? valor, String nombre) => Expanded(
      child: Semantics(
        label: '${valor ?? 'sin dato'} $nombre',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              valor?.toString() ?? '–',
              style: TextStyle(color: AppColors.primario, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(nombre, style: TextStyle(color: AppColors.textoSuave, fontSize: 11)),
          ],
        ),
      ),
    );
    Widget separador() => Container(width: 1, height: 30, color: AppColors.borde);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.cristal,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cristalBorde),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -12)],
      ),
      child: Row(
        children: [
          numero(resumen.pedidos, 'Pedidos'),
          separador(),
          numero(resumen.apartados, 'Apartados'),
          separador(),
          numero(resumen.favoritos, 'Favoritos'),
        ],
      ),
    );
  }
}

class _Opciones extends StatelessWidget {
  const _Opciones();

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<TemaProvider>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Renglon(icono: Icons.receipt_long_rounded, texto: 'Mis pedidos', onTap: () => Navigator.pushNamed(context, AppRoutes.misPedidos)),
          _Renglon(icono: Icons.bookmark_rounded, texto: 'Mis apartados', onTap: () => Navigator.pushNamed(context, AppRoutes.misApartados)),
          _Renglon(
            icono: Icons.auto_awesome_rounded,
            texto: 'Mis personalizaciones',
            onTap: () => Navigator.pushNamed(context, AppRoutes.misPersonalizaciones),
          ),
          _Renglon(
            icono: tema.oscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            texto: 'Tema oscuro',
            final_: Switch(
              key: const Key('perfil_tema'),
              value: tema.oscuro,
              onChanged: (oscuro) => tema.cambiar(oscuro: oscuro),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primario2,
              inactiveThumbColor: AppColors.primario2,
              inactiveTrackColor: AppColors.superficie2,
              trackOutlineColor: WidgetStatePropertyAll(AppColors.borde),
            ),
            onTap: () => tema.cambiar(oscuro: !tema.oscuro),
          ),
          _Renglon(icono: Icons.logout_rounded, texto: 'Cerrar sesión', peligro: true, onTap: () => cerrarSesionConConfirmacion(context)),
        ],
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({super.key, required this.icono, required this.texto, required this.onTap, this.final_, this.peligro = false});

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Widget? final_;
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    final color = peligro ? AppColors.error : AppColors.texto;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: peligro ? AppColors.error.withValues(alpha: 0.12) : AppColors.suave, borderRadius: BorderRadius.circular(14)),
              child: Icon(icono, size: 20, color: peligro ? AppColors.error : AppColors.primario),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            final_ ?? (peligro ? const SizedBox.shrink() : Icon(Icons.chevron_right_rounded, color: AppColors.textoSuave)),
          ],
        ),
      ),
    );
  }
}

// Hoja inferior para elegir de dónde sale la foto de perfil.
class _ElegirOrigen extends StatelessWidget {
  const _ElegirOrigen();

  @override
  Widget build(BuildContext context) {
    Widget opcion(IconData icono, String texto, ImageSource origen, Key key) =>
        _Renglon(key: key, icono: icono, texto: texto, onTap: () => Navigator.pop(context, origen));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Foto de perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            opcion(Icons.photo_library_rounded, 'Elegir de la galería', ImageSource.gallery, const Key('foto_galeria')),
            opcion(Icons.photo_camera_rounded, 'Tomar foto', ImageSource.camera, const Key('foto_camara')),
          ],
        ),
      ),
    );
  }
}
