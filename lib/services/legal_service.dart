import 'api_client.dart';

// Documentos legales que se aceptan al crear la cuenta (#321). Son los mismos textos que muestra
// el sitio web (tabla page_content), así que se editan en un solo lugar desde el panel de admin.
enum DocumentoLegal {
  terminos('terminos', 'Términos y condiciones'),
  privacidad('privacidad', 'Aviso de privacidad');

  const DocumentoLegal(this.pagina, this.nombre);
  final String pagina;
  final String nombre;
}

class TextoLegal {
  const TextoLegal({required this.titulo, required this.contenido});
  final String titulo;
  final String contenido;
}

class LegalException implements Exception {
  const LegalException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class LegalService {
  LegalService({required this._api});

  final ApiClient _api;
  final Map<DocumentoLegal, TextoLegal> _cache = {};

  Future<TextoLegal> obtener(DocumentoLegal doc) async {
    final guardado = _cache[doc];
    if (guardado != null) return guardado;
    try {
      final data = (await _api.dio.get('/content/pages/${doc.pagina}')).data as Map<String, dynamic>;
      final contenido = (data['contenido'] as String? ?? '').replaceAll('\r\n', '\n').trim();
      if (contenido.isEmpty) throw const LegalException('Este documento aún no está disponible.');
      final titulo = (data['titulo'] as String?)?.trim();
      return _cache[doc] = TextoLegal(titulo: titulo == null || titulo.isEmpty ? doc.nombre : titulo, contenido: contenido);
    } on LegalException {
      rethrow;
    } on Object {
      throw const LegalException('No se pudo cargar el documento. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
