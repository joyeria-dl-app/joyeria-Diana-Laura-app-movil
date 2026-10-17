// DATOS DE PRUEBA
// Tipo: datos compartidos · Alcance: todas las pruebas del emulador (integration_test/).
// Un solo lugar para los datos que usan las pruebas contra el backend real, en lugar de
// repetirlos en cada archivo. Detalle de cada dato y de cómo se limpia lo que crean las
// pruebas en pruebas/datos_de_prueba.md.
//
// Las cuentas no se escriben en el código: vienen de env.json en la computadora
// (--dart-define-from-file=env.json) y de los secretos del repositorio en los pipelines.
// Cada pipeline del emulador usa una cuenta distinta (PRUEBAS_*, ACEPTACION_* o ENTORNO_*)
// porque corren al mismo tiempo y se cambiaban el carrito (#185).

/// Cuenta de cliente de prueba con la que inicia sesión la prueba.
abstract final class CuentaPrueba {
  static const correo = String.fromEnvironment('PRUEBAS_CORREO');
  static const contrasena = String.fromEnvironment('PRUEBAS_CONTRASENA');
}

/// Registros del catálogo que usan las pruebas. Se pueden cambiar con --dart-define sin
/// tocar el código si la pieza deja de existir.
abstract final class PiezasPrueba {
  /// Pieza que admite personalización: Esclava personalizada Día del Padre.
  static const personalizable = int.fromEnvironment('PIEZA_PERSONALIZABLE', defaultValue: 1);

  /// Pieza con la que la prueba de seguridad arma un pedido de prueba.
  static const pedidoSeguridad = int.fromEnvironment('PIEZA_PEDIDO', defaultValue: 1);

  /// Categoría de donde las pruebas de compra toman la pieza más barata con existencia.
  static const categoriaCompra = 'Anillos';
}

/// Registros de OTRA cuenta (no la de prueba). La prueba de seguridad intenta verlos o
/// pagarlos y el backend debe rechazarlo.
abstract final class RegistrosAjenos {
  static const pedido = int.fromEnvironment('PEDIDO_AJENO', defaultValue: 16);
  static const apartado = int.fromEnvironment('APARTADO_AJENO', defaultValue: 4);
  static const abono = int.fromEnvironment('ABONO_AJENO', defaultValue: 4);
}

/// Opciones que activan los pasos que crean registros reales o necesitan a una persona.
abstract final class OpcionesPrueba {
  /// CA-10 a CA-13 de HU-11 crean una compra y un apartado reales.
  static const crearPedido = bool.fromEnvironment('CREAR_PEDIDO');

  /// La aceptación de HU-12 espera a que alguien pague en Mercado Pago.
  static const pagoMercadoPago = bool.fromEnvironment('PAGO_MP');

  /// Segundos de pausa para revisar a la vez el sitio web (0 en los pipelines).
  static const pausaWeb = int.fromEnvironment('PAUSA_WEB');
}

/// Límites de tiempo que comparten las pruebas del emulador.
abstract final class TiemposPrueba {
  /// Lo máximo que se espera a que aparezca algo en pantalla (Render puede estar despertando).
  static const espera = Duration(seconds: 90);

  /// Lo máximo que se espera a la tienda o a Mercado Pago en las pruebas con pasos a mano.
  static const pasoManual = Duration(minutes: 15);
}
