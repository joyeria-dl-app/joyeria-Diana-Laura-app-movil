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

**11 de 11 casos pasan.** No se encontró ninguna petición alterada que el backend aceptara.

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
