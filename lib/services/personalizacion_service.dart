import 'package:dio/dio.dart';

import '../models/personalizacion.dart';
import 'api_client.dart';

class PersonalizacionException implements Exception {
  const PersonalizacionException(this.mensaje, {this.sinSesion = false});
  final String mensaje;
  // El backend respondió 401: hay que iniciar sesión.
  final bool sinSesion;

  @override
  String toString() => mensaje;
}

// Solicitudes de personalización del cliente (HU-13). Usa los mismos endpoints que el sitio
// web: lo que se envía desde la app aparece en la pantalla de personalizaciones del trabajador.
class PersonalizacionService {
  PersonalizacionService({required this._api});

  final ApiClient _api;

  // El backend pide de 10 a 1000 caracteres; se revisa antes para no hacer la petición.
  static const minimoDetalle = 10;
  static const maximoDetalle = 1000;

  // POST /personalizacion/solicitudes. La imagen de referencia es opcional y se sube antes con subirReferencia().
  Future<SolicitudEnviada> solicitar({required int productoId, required String detalle, String? imagenReferencia}) async {
    final texto = detalle.trim();
    if (texto.length < minimoDetalle) {
      throw const PersonalizacionException('Describe la personalización con al menos 10 caracteres.');
    }
    if (texto.length > maximoDetalle) {
      throw const PersonalizacionException('El detalle no puede pasar de 1000 caracteres.');
    }
    final respuesta = await _pedir(
      () => _api.dio.post('/personalizacion/solicitudes', data: {'producto_id': productoId, 'detalle': texto, 'imagen_referencia_url': imagenReferencia}),
    );
    return SolicitudEnviada(
      solicitud: SolicitudPersonalizacion.fromJson(respuesta['data'] as Map<String, dynamic>),
      diasEstimados: (respuesta['dias_estimados'] as num?)?.toInt() ?? 3,
    );
  }

  // GET /personalizacion/mis-solicitudes, de la más reciente a la más antigua.
  Future<List<SolicitudPersonalizacion>> misSolicitudes() async {
    final respuesta = await _pedir(() => _api.dio.get('/personalizacion/mis-solicitudes'));
    return [for (final s in (respuesta['data'] as List<dynamic>? ?? const [])) SolicitudPersonalizacion.fromJson(s as Map<String, dynamic>)];
  }

  // POST /upload/image en la carpeta de personalizaciones, igual que el sitio web. Devuelve la URL de la imagen.
  Future<String> subirReferencia(List<int> bytes, String nombreArchivo) async {
    final respuesta = await _pedir(
      () => _api.dio.post(
        '/upload/image',
        data: FormData.fromMap({'imagen': MultipartFile.fromBytes(bytes, filename: nombreArchivo), 'folder': 'joyeria/personalizaciones'}),
      ),
    );
    final url = (respuesta['data'] as Map<String, dynamic>?)?['url'] as String?;
    if (url == null) throw const PersonalizacionException('No se pudo subir la imagen. Intenta con otra foto.');
    return url;
  }

  Future<Map<String, dynamic>> _pedir(Future<Response<dynamic>> Function() peticion) async {
    try {
      final data = (await peticion()).data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw PersonalizacionException(data['message'] as String? ?? 'No se pudo enviar tu solicitud.');
      }
      return data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const PersonalizacionException('Inicia sesión para solicitar una personalización.', sinSesion: true);
      }
      // 400 y 404 traen un mensaje entendible, por ejemplo "Este producto no admite personalización".
      final mensaje = switch (e.response?.data) {
        {'message': final String m} when status == 400 || status == 404 => m,
        _ => null,
      };
      throw PersonalizacionException(mensaje ?? 'No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
