# Prueba de integración · Sprint 3 (HU-09, HU-11, HU-12 y HU-13)

**Tarea:** #146 · **Fecha:** 11 de octubre de 2026 · **Prueba:** `integration_test/integracion_compra_test.dart`

**Criterio de aceptación:** el pedido se crea en el backend y su estado se ve en la app.

Un solo recorrido en el emulador contra el backend real que une las historias del sprint: carrito → pedido → la tienda lo confirma → pago con Mercado Pago → pedido pagado → solicitud de personalización. En cada paso se compara lo que muestra la app con lo que registra el servidor.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8 (API 34) |
| Backend | Render (producción del proyecto) |
| Cliente | Cuenta de pruebas (secreto `PRUEBAS_CORREO`) |
| Mercado Pago | Vendedor y comprador de prueba; pago con el saldo del comprador, sin cobros reales |
| Tienda | La confirmación y la limpieza se hicieron en la base de datos con un script |

La prueba avisa con `INTEGRACION PASO` cuándo confirma la tienda, cuándo hay que pagar y qué limpiar. Por eso no corre en los pipelines (igual que la aceptación de HU-12, #44).

```
flutter test integration_test/integracion_compra_test.dart --dart-define-from-file=env.json
```

## Resultados

| Caso | HU | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|---|
| I-01 | HU-09 | La pieza más barata de Anillos llega al carrito con su precio ($449.50) | Pasa | 265 |
| I-02 | HU-11 | El pedido DL-1791764744684 se crea pendiente en el servidor con el mismo total y aparece en Mis pedidos | Pasa | 266 |
| I-03 | HU-11 | La tienda lo confirma y el seguimiento ofrece "Paga con Mercado Pago" | Pasa | 267 |
| I-04 | HU-12 | Pago con el comprador de prueba (operación MP 183705160246): la app muestra "¡Pago recibido!" y el webhook marca el pedido pagado | Pasa | 268 |
| I-05 | HU-12 | El seguimiento del pedido pagado ya no ofrece pagar y muestra el código de entrega | Pasa | 269 |
| I-06 | HU-13 | La solicitud de personalización 5 queda pendiente en el servidor y Mis personalizaciones la muestra en revisión | Pasa | 270 |

**6 de 6 casos pasan.** La pantalla "¡Pago recibido!" no tiene captura propia (pasó mientras se revisaba la página de Mercado Pago); la prueba sí comprobó ese texto en la app y el pago en el servidor.

## Limpieza

El pedido 19 (DL-1791764744684) quedó cancelado y su pieza regresó al stock, como hace el backend al cancelar un pedido pagado. La solicitud 5 quedó rechazada con el motivo "Solicitud de prueba de la tarea #146".
