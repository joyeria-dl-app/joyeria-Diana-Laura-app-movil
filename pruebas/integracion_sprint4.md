# Prueba de integración · Sprint 4 (app completa, HU-03 a HU-16)

**Tarea:** #151 · **Fecha:** 5 de noviembre de 2026 · **Prueba:** `integration_test/integracion_app_test.dart`

**Criterio de aceptación:** el recorrido completo pasa contra el backend real.

Un solo recorrido en el emulador contra el backend real que une las historias de la app: iniciar sesión → Inicio → catálogo por páginas de 5 → carrito → pedido → la tienda lo confirma → Mi perfil y Mis pedidos → zonas de entrega. En cada paso se compara lo que muestra la app con lo que registra el servidor.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8 (API 36, con Google Play) |
| Backend | Render (producción del proyecto) |
| Cliente | Cuenta de pruebas (secreto `PRUEBAS_CORREO`) |
| Pago | Efectivo en tienda (Mercado Pago ya se probó en la integración del Sprint 3, #146) |
| Tienda | `Backend/_tienda151.js`: confirma el pedido y manda el mismo push que `PATCH /pedidos/:id/estado`; al final lo cancela |
| Avisos | La prueba inicia Firebase y los avisos del pedido como `main.dart`, así el emulador queda registrado para recibir push |

La prueba avisa con `INTEGRACION PASO` cuándo confirma la tienda y qué limpiar. Por eso no corre en los pipelines (igual que la del Sprint 3).

```
flutter test integration_test/integracion_app_test.dart --dart-define-from-file=env.json
```

## Resultados

| Caso | HU | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|---|
| I-01 | HU-03, #244 | Inicia sesión y el Inicio saluda a la cuenta ("Buenas tardes") | Pasa | 168 |
| I-02 | HU-05, #269 | El chip de Anillos abre la categoría con 5 piezas y al bajar llegan 5 más (10) | Pasa | 169 |
| I-03 | HU-06, HU-09 | La pieza más barata con existencia llega al carrito con su precio ($449.50) | Pasa | 170 |
| I-04 | HU-11, HU-16 | El pedido DL-1793903309775 en tienda y en efectivo se crea pendiente en el servidor con el mismo total | Pasa | 171 |
| I-05 | HU-15 | La tienda lo confirma, el servidor lo registra confirmado y Firebase acepta el push para el emulador (1 enviado, 0 fallidos) | Pasa con observación | 172, 172a |
| I-06 | HU-14 | Mi perfil → Mis pedidos muestra el pedido y su seguimiento confirmado | Pasa | 173 |
| I-07 | HU-16 | Mi perfil abre las zonas de entrega del servidor | Pasa | 174 |

**7 de 7 casos pasan.**

## Observaciones

- **Notificación en el emulador (I-05).** El emulador quedó registrado (el servidor encontró 1 teléfono de la cuenta) y Firebase aceptó el envío, pero la notificación no apareció en la barra del emulador mientras corría la prueba (evidencia 172a). La prueba no puede leer las notificaciones del sistema; que el aviso se vea y que al tocarlo abra el pedido se comprueba en un teléfono real en la #57.
- **Build de perfil.** Se intentó correr la prueba con `flutter drive --profile` (compilada AOT como producción, con `test_driver/integration_test.dart`), pero el inicio de sesión no entró en ninguno de los 3 intentos y el servidor no registró intentos fallidos. En modo debug, como en los pipelines, pasa. El build de producción se revisa en rendimiento (#154) y en el teléfono real (#57).

## Limpieza

Los pedidos de las dos corridas (DL-1793902309885 y DL-1793903309775) quedaron cancelados con la nota "Prueba de integración #151".
