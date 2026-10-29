import '../models/banner_inicio.dart';
import 'api_client.dart';

// Contenido del Inicio que administra la tienda (#244). Es público, como en el sitio web.
class InicioService {
  InicioService({required this._api});

  final ApiClient _api;

  // Banners activos del carrusel en el orden del panel; los que no tienen título ni foto se omiten.
  Future<List<BannerInicio>> carrusel() async {
    final data = (await _api.dio.get('/content/carrusel-inicio')).data;
    final lista = data is List ? data : (data is Map ? data['data'] as List? : null) ?? const [];
    return [
      for (final b in lista)
        if (b is Map<String, dynamic> && b['activo'] != false) BannerInicio.fromJson(b),
    ].where((b) => b.titulo.isNotEmpty && b.imagen != null).toList();
  }
}
