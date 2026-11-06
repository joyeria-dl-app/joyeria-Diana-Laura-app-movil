# Pruebas de aceptación HU-14 y HU-16 · Perfil, historial, zonas de entrega y accesibilidad

**Tarea:** #152 · **Fecha:** 5 de noviembre de 2026 · **Prueba:** `integration_test/aceptacion_perfil_test.dart`

**Criterios de aceptación:**
- HU-14: el cliente ve sus datos y su historial, y puede cerrar sesión.
- HU-16: el cliente ve las mismas zonas de entrega que administra el negocio en el sitio web.
- Accesibilidad: lo que se toca mide al menos 48 × 48 dp y tiene una etiqueta para TalkBack, y el texto cumple el contraste mínimo de WCAG (4.5:1, o 3:1 si es grande).

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8 (API 36), tema oscuro |
| Backend | Render (producción del proyecto) |
| Cliente | Cuenta de pruebas (secreto `PRUEBAS_CORREO`) |
| Reglas de accesibilidad | `androidTapTargetGuideline`, `labeledTapTargetGuideline` y `textContrastGuideline` de Flutter |

La prueba solo lee: no crea pedidos ni cambia datos. Cada pantalla se compara con lo que devuelve el servidor para la misma cuenta (`/auth/profile`, `/carrito/pedidos/mis`, `/apartados/mis-apartados`, `/zonas-entrega`).

```
flutter test integration_test/aceptacion_perfil_test.dart --dart-define-from-file=env.json
```

## Resultados

| Caso | HU | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|---|
| CA-35 | 14 | Mi perfil muestra el nombre, el correo y 19 pedidos, 3 apartados y 0 favoritos, igual que el servidor | Pasa | 193 |
| CA-36 | Accesibilidad | Mi perfil: botones de 48 dp, con etiqueta y texto con contraste suficiente | Pasa | 193 |
| CA-37 | 14 | Mis pedidos: 1 en curso y 18 cancelados (el más reciente, DL-1793914954865), igual que el servidor; la pantalla cumple las tres reglas | Pasa | 193a, 193b |
| CA-38 | 14 | Mis apartados muestra los 3 apartados del servidor y cumple las tres reglas | Pasa | 193c |
| CA-39 | 16 | Zonas de entrega muestra las 5 zonas activas del servidor: Huejutla, San Felipe, Jaltocan, Tampico y Tehuetlan | Pasa | 193d, 193e |
| CA-40 | Accesibilidad | Zonas de entrega cumple las tres reglas (ver la nota de contraste) | Pasa | 193d, 193e |
| CA-41 | 14 | Cerrar sesión pide confirmación y Cancelar deja la sesión abierta | Pasa | 193f |
| CA-42 | 14 | Al confirmar se cierra la sesión y la app pide iniciar sesión de nuevo | Pasa | 193g |

**8 de 8 casos pasan.**

## Hallazgos de accesibilidad corregidos

La primera corrida falló en las reglas de accesibilidad. Los problemas eran de la app y se corrigieron en este mismo cambio:

| Hallazgo | Dónde | Antes | Corrección |
|---|---|---|---|
| Interruptor sin etiqueta | Mi perfil, "Tema oscuro" | TalkBack leía "Activado, interruptor" sin decir de qué | Se le dio la etiqueta "Tema oscuro" |
| Texto blanco sobre el degradado rosa | Pestaña activa de la barra inferior, botones con degradado, tarjeta del pedido en curso, chip de estado y cabecera de Mi perfil | Contraste de 1.8 a 4.3:1 | Texto e iconos en `AppColors.sobreDegradado` (#0D080C): de 4.6 a 10.8:1 en los dos temas |
| Botones pequeños | Regresar y ajustes (`BotonCristal`), botones de la cabecera del perfil y del seguimiento | 40 a 44 dp | 48 dp |
| Botón bajo | Zonas de entrega, "Cómo llegar" | 41 dp de alto | 49 dp |

La cabecera de Mi perfil pasó la regla de Flutter aun con texto blanco; se encontró al medir los píxeles de la captura (2.0 a 2.9:1) y se corrigió igual. Con texto oscuro el nombre queda en 4.6:1 y el correo en 7.5:1.

## Nota: contraste del inicio de Zonas de entrega

Arriba de Zonas de entrega, la regla de contraste de Flutter marca 1.1:1 en "ENTREGAS A DOMICILIO" y en el texto de introducción. El antetítulo se pinta con un degradado (`ShaderMask`) y hay destellos animados encima; la regla toma el color del texto antes del degradado. Medido con los píxeles de la captura 193d, el contraste real es de **10.8:1** y **9.2:1**. Por eso en esa vista la prueba revisa el tamaño y las etiquetas de los botones, y el contraste queda medido a mano. Al final de la lista las tres reglas pasan.

## Corridas

1. Falló la regla de etiquetas: el interruptor de Tema oscuro.
2. Falló la regla de contraste: el texto blanco de la barra inferior.
3. Mis pedidos no mostró el pedido más reciente: estaba en la pestaña Cancelados. Error de la prueba, no de la app; ahora revisa En curso y Cancelados.
4. Falló la regla de 48 dp: el botón de regresar (44 dp).
5. Falló la regla de 48 dp: "Cómo llegar" (41 dp).
6. Una corrida no pudo iniciar sesión porque el servidor tardó en responder; se repitió sin cambios.
7. a 9. Contraste del inicio de Zonas: la prueba no estaba subiendo la lista y después quedó la falsa alarma del degradado (nota anterior).
10. 8 de 8, después de corregir también la cabecera de Mi perfil. Es la corrida de la tabla.

Las 377 pruebas unitarias siguen pasando con los cambios.
