# Pruebas de aceptación HU-13 · Solicitar la personalización de una pieza

**Tarea:** #147 · **Fecha:** 11 de octubre de 2026 · **Prueba:** `integration_test/aceptacion_personalizacion_test.dart`

**Criterio de aceptación:** el cliente envía una solicitud desde la app y aparece en el sistema del negocio.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8 (API 34) |
| Backend | Render (producción del proyecto) |
| Cliente | Cuenta de pruebas (secreto `PRUEBAS_CORREO`) |
| Pieza | Esclava personalizada Día del Padre (id 1, admite personalización) |

La aprobación o el rechazo los hace el personal desde el sitio web (fuera del alcance de HU-13). La prueba avisa con `ACEPTACION PASO` cuándo toca revisar la solicitud en el sistema del negocio y cuándo rechazarla; por eso no corre en los pipelines y cada corrida deja una solicitud real, que se cierra como rechazada.

```
flutter test integration_test/aceptacion_personalizacion_test.dart --dart-define-from-file=env.json
```

## Resultados

| Caso | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|
| CA-21 | La pieza que admite personalización muestra "¿La quieres a tu gusto?" en su detalle | Pasa | 232 |
| CA-22 | Con 7 caracteres el formulario avisa cuántos faltan y no se envía nada al servidor | Pasa | 233 |
| CA-23 | La solicitud se envía, la app confirma los días de revisión y el servidor la registra pendiente (solicitud 4) | Pasa | 234 |
| CA-24 | Mis personalizaciones muestra la solicitud "En revisión" | Pasa | 235 |
| CA-25 | La tienda la rechaza con un motivo y la app la muestra "No aprobada" con ese motivo | Pasa | 236 |

**5 de 5 casos pasan.**

## Corridas

Se hicieron tres corridas; cada una dejó una solicitud que se cerró como rechazada (ids 2, 3 y 4).

1. Solicitud 2: los 5 casos pasaron, pero las capturas quedaron desfasadas porque la prueba avanzaba más rápido que la toma de pantalla. Se agregó una pausa de 4 segundos después de cada caso.
2. Solicitud 3: falló CA-25. El motivo de rechazo era el mismo que el de la solicitud 2 y la prueba encontró dos textos iguales. Fallo de la prueba, no de la app: el motivo ahora incluye el id de la solicitud.
3. Solicitud 4: 5 de 5. Es la corrida de la tabla.
