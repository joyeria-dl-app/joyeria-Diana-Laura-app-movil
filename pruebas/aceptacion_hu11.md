# Pruebas de aceptación · Sprint 3 (HU-11)

- **Prueba automatizada:** `integration_test/aceptacion_pedidos_test.dart`
- **Pipeline:** `.github/workflows/pruebas-aceptacion.yml` (CA-14 y CA-15 en cada integración a develop); también en `pruebas-regresion.yml`.
- **Entorno:** emulador de Android (Android Studio, perfil Pixel 8), app en modo debug, backend real de Render.
- **Cuenta:** cliente de prueba (secretos `PRUEBAS_CORREO` y `PRUEBAS_CONTRASENA`).
- **Pieza usada:** el anillo más barato con al menos 2 piezas en existencia. En esta corrida: "Anillo de promesa piedra rosa baño en rodio" ($449.50).
- **Compra y apartado reales:** CA-10 a CA-13 crean un pedido y un apartado en la tienda, por eso solo corren con `--dart-define=CREAR_PEDIDO=true` y no en el pipeline. Al terminar, los registros de prueba se cancelan con el motivo "Registro de prueba de aceptación HU-11 (#39)"; como seguían pendientes, no habían descontado inventario.
- **"Sitio web":** se comprueba con lo que devuelve el servidor para la misma cuenta, que es de donde lee el sitio web, y con capturas del sitio.
- **Fecha de ejecución:** 6 de octubre de 2026.

## Criterio de aceptación

| HU | Criterio |
|---|---|
| HU-11 | El cliente compra o aparta una pieza desde la app; el pedido queda registrado en la tienda y puede ver su estado en la app, igual que en el sitio web. |

## Casos

| Caso | Qué se comprueba | Resultado obtenido | Resultado | Evidencia |
|---|---|---|---|---|
| CA-10 | Compra para recoger en tienda con efectivo: el pedido queda en el servidor y el carrito se vacía | Pedido DL-1791273030029 de $449.50 en estado Pendiente; carrito vacío | Pasa | 60, 64 |
| CA-11 | El pedido aparece en Mis pedidos y su seguimiento muestra el estado | Aparece en En curso; seguimiento en "Pedido recibido", Pendiente | Pasa | 63 |
| CA-12 | Apartado con el 50% y plan Semanal: queda en el servidor | Apartado APT-20261006-8NCO3, plan Semanal, abono de hoy $224.75 | Pasa | 61, 59 |
| CA-13 | Aparece en Mis apartados con el pago inicial pendiente y aún no deja abonar | "Pago inicial pendiente"; al tocar Abonar avisa que podrá abonar cuando la tienda confirme | Pasa | 62 |
| CA-14 | Mis pedidos de la app coincide con el sitio web | App "En curso · 3" y sitio web "3 En proceso", mismos folios | Pasa | 65 |
| CA-15 | Mis apartados de la app coincide con el servidor | 3 apartados activos en la app y en el servidor | Pasa | 62 |

**Resultado:** 6 de 6 casos pasan. Se cumple el criterio de aceptación de HU-11.

Inicio de la tarea: evidencia 58.

## Observaciones

- La primera corrida falló en CA-12: la prueba buscaba el folio del apartado con el prefijo "AP-", pero el sistema los genera como "APT-AAAAMMDD-XXXXX". La app funcionó bien (evidencia 59: el apartado APT-20261006-YG02J se creó); se corrigió la búsqueda en la prueba y la segunda corrida pasó completa. El pedido y el apartado de la primera corrida también se cancelaron.

## Cómo ejecutarla

```
flutter test integration_test/aceptacion_pedidos_test.dart --dart-define-from-file=env.json --dart-define=CREAR_PEDIDO=true
```

Con `--dart-define=PAUSA_WEB=40` se detiene 40 s en CA-14 para tomar la captura del sitio web. Sin `CREAR_PEDIDO` solo corren CA-14 y CA-15, que no crean nada.
