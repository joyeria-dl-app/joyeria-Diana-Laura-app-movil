# Pruebas de seguridad del pago · Sprint 3 (HU-19, tarea #98)

**Fecha:** 11 de octubre de 2026 · **Prueba:** `integration_test/seguridad_pago_test.dart`

**Qué se prueba:** una app modificada puede mandar al backend cualquier petición. La prueba inicia sesión en el emulador con la cuenta de prueba y, con el mismo cliente HTTP de la app, manda peticiones de pago alteradas. El backend debe rechazarlas y el pedido no debe cambiar.

```
flutter test integration_test/seguridad_pago_test.dart --dart-define-from-file=env.json
```

No corre en los pipelines: crea un pedido real de la cuenta de prueba, que se cancela en la base de datos al terminar.

## Resultados

| # | Petición alterada | Respuesta del backend | Resultado |
|---|---|---|---|
| SP-01 | Agregar al carrito con `precio_venta: 1` | Guarda el precio del catálogo ($900.55) | Pasa |
| SP-02 | Cantidades 0, -3 y 100000 | 400 | Pasa |
| SP-03 | Pedido a domicilio con `costo_envio: 0` y `total: 1` | Cobra el envío de la configuración ($200) y total $1,100.55 | Pasa |
| SP-04 | Enlace de Mercado Pago para un pedido que la tienda no ha confirmado | 400 | Pasa |
| SP-05 | Apartado con abono de 20%, 200%, `"abc"` y -10 | 400 | Pasa |
| SP-06 | Ver o pagar (Mercado Pago y PayPal) el pedido 16, el apartado 4 y el abono 4 de otra cuenta | 403 / 404 | Pasa |
| SP-07 | Como cliente: marcar el pedido entregado, confirmar pago en efectivo y confirmar pago de apartado | 403 | Pasa |
| SP-08 | Aviso falso de Mercado Pago (pago inexistente con la referencia del pedido) en pedidos y apartados | El pedido sigue `pendiente` y no se registra ninguna transacción | Pasa |
| SP-09 | Captura de PayPal con una orden inventada | 400 y el pedido sigue sin pagar | Pasa |
| SP-10 | Sin sesión: enlace de pago, crear pedido y recibo | 401 | Pasa |
| SP-11 | Token inventado | 401 / 403 | Pasa |
| SP-12 | Ver el detalle (`GET /apartados/4`) del apartado de otra cuenta | 404 (antes de la corrección: 200 con piezas, abonos y comprobante) | **Fallaba → corregido** (#216) |

**12 de 12 casos pasan.** SP-12 se agregó el 17 de octubre de 2026 (ver abajo).

## Hallazgo corregido: ver el apartado de otra cuenta (#216)

Al preparar el historial de abonos de la HU-14 (#51) se encontró que `GET /apartados/:id` no revisaba de quién era el apartado: con la cuenta de prueba se pudo ver el apartado 4 de otra clienta (HTTP 200), con sus piezas, montos, abonos y la URL del comprobante. La prueba SP-06 revisaba que no se pudiera **pagar** un apartado ajeno, no que no se pudiera **ver**.

- **Corrección en el backend** (repositorio Joyeria-Diana-Laura, PR #4): el endpoint responde 404 si el apartado no es del cliente; el personal lo sigue viendo. Publicado el 17 de octubre de 2026; desde entonces el apartado 4 responde 404 y los apartados propios siguen respondiendo 200.
- **Prueba:** nuevo caso SP-12.
- **Error en la propia prueba, corregido:** al pasar los datos a `datos_prueba.dart` (#208), las direcciones de SP-06 quedaron como `'/carrito/pedidos/$RegistrosAjenos.pedido'`, que Dart convierte en `/carrito/pedidos/RegistrosAjenos.pedido` en lugar de `/carrito/pedidos/16`. La prueba pasaba porque esa dirección también se rechaza, pero no probaba el pedido real. Se cambió a `${RegistrosAjenos.pedido}` en todas las pruebas del emulador. Pedido de prueba de esta corrida: 21, cancelado y sin transacciones.

## Revisado en el código, sin prueba automática

- El enlace de Mercado Pago de un pedido confirmado arma los artículos y el monto con lo guardado en el servidor, no con lo que manda la app (`crearPreferenciaMercadoPago`).
- El aviso de Mercado Pago consulta el pago directamente en Mercado Pago y compara el monto con el total del pedido antes de marcarlo pagado; un mismo pago no se procesa dos veces (`webhookMercadoPago`).
- Un pedido con el plazo vencido o ya pagado no recibe enlace de pago.

Estos casos necesitan que el personal confirme un pedido, por eso no se automatizaron; el pago aprobado con Mercado Pago ya se probó en la aceptación de HU-12 (#44).

## Corridas

1. Falló SP-01 por un error de la prueba: esperaba 201 al agregar al carrito y el backend responde 200. No llegó a crear pedido.
2. Falló SP-11 por un error de la prueba: con un token inválido el backend responde 403 y la prueba solo aceptaba 401. SP-01 a SP-10 pasaron. Pedido de prueba 17.
3. 11 de 11. Pedido de prueba 18.

Los pedidos 17 y 18 quedaron cancelados y sin transacciones de pago.

## Pendiente para el Sprint 4 (#99)

La app no detecta teléfonos con root. Con root se puede modificar la app, pero, como muestra esta prueba, el backend no acepta pagos ni montos alterados.
