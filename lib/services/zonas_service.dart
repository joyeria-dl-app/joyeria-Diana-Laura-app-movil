import '../models/zona_entrega.dart';
import 'api_client.dart';

class ZonasException implements Exception {
  const ZonasException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

// Zonas de entrega (HU-16, #60). Usa los mismos endpoints públicos que el sitio web, así que no
// hace falta iniciar sesión para consultarlas.
class ZonasService {
  ZonasService({required this._api});

  final ApiClient _api;

  // Zonas activas en el orden de la tienda, más dirección, horario y WhatsApp. Si una consulta
  // falla se muestra la otra; si fallan las dos, no hay nada que mostrar.
  Future<InfoEntregas> entregas() async {
    final (zonas, tienda) = await (_opcional(_zonas), _opcional(_tienda)).wait;
    if (zonas == null && tienda == null) {
      throw const ZonasException('No se pudieron cargar las zonas de entrega. Revisa tu conexión e intenta de nuevo.');
    }
    return InfoEntregas(zonas: zonas, direccion: _texto(tienda?['direccion']), horario: _texto(tienda?['horario']), whatsapp: _digitos(tienda?['whatsapp']));
  }

  Future<List<ZonaEntrega>> _zonas() async {
    final data = (await _api.dio.get('/zonas-entrega')).data as Map<String, dynamic>;
    final zonas = [
      for (final z in (data['data'] as List<dynamic>? ?? const []))
        if ((z as Map<String, dynamic>)['activo'] != false) ZonaEntrega.fromJson(z),
    ].where((z) => z.nombre.isNotEmpty).toList();
    // El backend ya las ordena; se vuelve a ordenar por si la respuesta llega de la caché sin orden.
    zonas.sort((a, b) => a.orden != b.orden ? a.orden.compareTo(b.orden) : a.nombre.compareTo(b.nombre));
    return zonas;
  }

  Future<Map<String, dynamic>> _tienda() async {
    final data = (await _api.dio.get('/content/info-empresa')).data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>? ?? const {};
  }

  Future<T?> _opcional<T>(Future<T> Function() consulta) async {
    try {
      return await consulta();
    } on Object {
      return null;
    }
  }

  static String? _texto(Object? valor) {
    final t = (valor as String?)?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static String? _digitos(Object? valor) {
    final d = (valor as String? ?? '').replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }
}
