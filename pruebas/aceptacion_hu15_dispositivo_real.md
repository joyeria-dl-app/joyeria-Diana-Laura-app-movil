# Prueba de aceptación HU-15 · Notificación del pedido en un dispositivo real

**Tarea:** #57 · **Fecha:** 5 de noviembre de 2026 · **Tipo:** prueba manual en teléfono físico

**Criterio de aceptación:** cuando la tienda cambia el estado de un pedido, el cliente recibe una notificación en su teléfono y al tocarla se abre el seguimiento de ese pedido.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Motorola Moto G6 Plus, Android 9, 360 dp de ancho, conectado por USB |
| App | APK de release de `develop` (commit 032f944, con las páginas numeradas de #279), versión 0.3.0, instalado con adb |
| Backend | Render (producción del proyecto) y Firebase Cloud Messaging |
| Cliente | Cuenta de pruebas, sesión iniciada en el teléfono |
| Pedido | DL-1793914954865: 1 pieza de $500.00, entrega y pago en tienda |

En Android 9 el sistema no pide permiso para mostrar notificaciones (ese permiso existe desde Android 13); se revisó con `adb shell dumpsys notification` que la app tiene el canal **Pedidos** con importancia alta.

La confirmación la hizo la tienda con el script de la prueba de integración (#151), que cambia el estado igual que `PATCH /pedidos/:id/estado` y manda el mismo aviso del backend.

## Resultados

| Caso | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|
| CA-31 | Al enviar el pedido llega la notificación "Recibimos tu pedido" | Pasa | 185 |
| CA-32 | La tienda confirma el pedido; el servidor reporta 1 envío y 0 fallidos y en el teléfono aparece "Pedido confirmado" | Pasa | 185a |
| CA-33 | Las dos notificaciones quedan en la barra con el nombre de la app; `dumpsys notification` muestra el texto con el folio | Pasa | 185b |
| CA-34 | Al tocar la notificación se abre el seguimiento del pedido en estado Confirmado (15:43) | Pasa | 185c |

**4 de 4 casos pasan.**

En la prueba de integración del Sprint 4 la notificación salió del servidor pero no se vio en el emulador; en el teléfono real sí llega, lo que confirma que la falta era del emulador.

Al terminar, el pedido de prueba se canceló en la base de datos.
