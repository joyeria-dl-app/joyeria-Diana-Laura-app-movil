# Prueba de aceptación #274 · Oponerse a los avisos (ARCO, oposición)

**Tarea:** #274 · **Fecha:** 6 de noviembre de 2026 · **Tipo:** prueba manual en teléfono físico

**Criterio de aceptación:** con el interruptor apagado no llega el aviso push del cambio de estado.

## Qué hace

- **Base de datos** (migración `preferencias_avisos_usuarios` en Supabase): `usuarios.avisos_push` y `usuarios.correos_promocion`, con valor por defecto `true`; nadie deja de recibir avisos hasta que lo pide.
- **Backend** (joyeria258076-cell/Joyeria-Diana-Laura#11): `GET` y `PUT /notificaciones/preferencias`. La función que envía los avisos push del pedido (`enviarAUsuario`) solo toma los teléfonos de cuentas con `avisos_push` activo, y el envío de promociones por correo omite a quien tiene `correos_promocion = false`.
- **App:** en Mi perfil, los interruptores "Avisos de mis pedidos" y "Correos de promociones", con etiqueta para TalkBack. Se leen y se guardan en el servidor; si no se pueden guardar, el interruptor regresa a como estaba y se muestra el motivo.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Motorola Moto G6 Plus, Android 9 |
| App | APK de release de la rama `feature/preferencias-avisos` |
| Backend | Render, con el PR #11 desplegado |
| Cuenta | Cuenta de pruebas (usuario 42), con un teléfono registrado para avisos |
| Envío | `Backend/_push274.ts`: llama a la misma función `enviarAUsuario` del backend que avisan los cambios de estado del pedido; no cambia ningún pedido |

## Resultados

| Caso | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|
| CA-47 | Mi perfil muestra los dos interruptores encendidos (valor del servidor) | Pasa | 204 |
| CA-48 | Con "Avisos de mis pedidos" encendido, el backend envía el aviso (1 enviado) y llega al teléfono | Pasa | 204a, 204c |
| CA-49 | Se apaga el interruptor en la app; en la base queda `avisos_push = false` y el backend envía 0 avisos: no llega nada al teléfono | Pasa | 204b, 204c |
| CA-50 | Se vuelve a encender en la app y la base regresa a `avisos_push = true` | Pasa | 204c |

**4 de 4 casos pasan.** `dumpsys notification` en el teléfono muestra solo el aviso de CA-48.

## Pruebas automatizadas

En `test/perfil_flujo_test.dart` (backend simulado): apagar los avisos y guardar en el servidor, apagar los correos desde el renglón, interruptor que regresa si el guardado falla, y mostrar las preferencias que ya estaban guardadas. Con ellas pasan 395 pruebas.
