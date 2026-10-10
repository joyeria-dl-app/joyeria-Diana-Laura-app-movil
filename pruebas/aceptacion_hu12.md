# Pruebas de aceptación HU-12 · Pagar con Mercado Pago desde la app

**Tarea:** #44 · **Fecha:** 10 de octubre de 2026 · **Prueba:** `integration_test/aceptacion_pago_test.dart`

**Criterio de aceptación:** el cliente paga un pedido confirmado o el pago inicial de un apartado con Mercado Pago desde la app; al regresar, la app le dice si el pago quedó aprobado o no se completó, y lo que ve coincide con lo que registra el servidor.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8 (API 34) |
| Backend | Render (producción del proyecto) |
| Cliente | Cuenta de aceptación (secreto `ACEPTACION_CORREO`) |
| Mercado Pago | Vendedor de prueba y comprador de prueba (`TESTUSER…`); no hay cobros reales |
| Tarjeta de prueba | Mastercard 5474 9254 3267 0366, titular `OTHE` (rechazada) |
| Pago aprobado | Saldo disponible del comprador de prueba |

La prueba avisa con `ACEPTACION PASO` lo que hace la persona que prueba: confirmar el pedido como la tienda y pagar en la página de Mercado Pago. Por eso no corre en los pipelines.

```
flutter test integration_test/aceptacion_pago_test.dart --dart-define-from-file=env.json --dart-define=PAGO_MP=true
```

## Resultados

| Caso | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|
| CA-16 | Compra con Mercado Pago para recoger en tienda; al confirmarla la tienda, el seguimiento ofrece "Paga con Mercado Pago" | Pasa (DL-1791664891800) | 158, 159 |
| CA-17 | Pago con tarjeta rechazada: la app muestra "El pago no se completó", "Sin pagar", y el servidor no marca el pedido pagado | Pasa (operación MP 182503156905, `cc_rejected_other_reason`) | 163, 164, 165 |
| CA-18 | "Intentar de nuevo" y pago aprobado: la app muestra "¡Pago recibido!" y el webhook marca el pedido pagado en el servidor | Pasa (operación MP 183522124416, $449.50) | 166 |
| CA-19 | El pedido pagado ya no ofrece pagar | Pasa | — |
| CA-20 | Pago inicial de un apartado (plan semanal) con Mercado Pago: "¡Pago recibido!" y el apartado queda activo en el servidor | Pasa (APT-20261010-WZQ5O, operación MP 182503533053, $224.75) | 167, 168 |

**5 de 5 casos pasan.**

## Problema encontrado durante la prueba

En la primera corrida Mercado Pago respondía "No pudimos procesar tu pago" con cualquier tarjeta y no registraba ningún pago (evidencias 160 a 162). La causa: el vendedor era una cuenta de prueba y el comprador, la cuenta de aceptación con un correo real; Mercado Pago no permite mezclar cuentas de prueba y reales. Se creó un comprador de prueba y se pagó con él. La app no necesitó cambios: con el pago no procesado ya mostraba "El pago no se completó".

También se amplió la espera de la prueba de 6 a 15 minutos, porque iniciar sesión con el comprador de prueba en Mercado Pago tarda más de 6 minutos la primera vez.

Al terminar, la tienda canceló el pedido y el apartado de prueba.
