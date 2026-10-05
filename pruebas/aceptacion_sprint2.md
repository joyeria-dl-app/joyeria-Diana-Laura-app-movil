# Pruebas de aceptación · Sprint 2 (HU-08, HU-09 y HU-10)

- **Prueba automatizada:** `integration_test/aceptacion_test.dart`
- **Pipeline:** `.github/workflows/pruebas-integracion.yml`
- **Entorno:** emulador de Android (Android Studio, perfil Pixel 8), app en modo debug, backend real de Render.
- **Cuenta:** cliente de prueba (secretos `PRUEBAS_CORREO` y `PRUEBAS_CONTRASENA`); la prueba deja el carrito y los favoritos vacíos al terminar.
- **Pieza usada:** el primer anillo con existencias y más de una foto. En esta corrida: "Anillos de plata ley .925 para compromiso, promesa o arras de matrimonio" (6 fotos, $580.32).
- **"Sitio web":** se comprueba con lo que devuelve el servidor para la misma cuenta, que es de donde lee el sitio web, y con capturas del sitio.
- **Fecha de ejecución:** 5 de octubre de 2026.

## Criterios de aceptación

| HU | Criterio |
|---|---|
| HU-08 | Al tocar una pieza del catálogo se muestra su detalle y se pueden deslizar todas sus imágenes. |
| HU-09 | El cliente agrega piezas y el carrito de la app coincide con el que ve en el sitio web con la misma cuenta. |
| HU-10 | Una pieza marcada como favorita aparece en la lista de favoritos del cliente, también en el sitio web. |

## Casos

| Caso | HU | Qué se comprueba | Resultado obtenido | Resultado | Evidencia |
|---|---|---|---|---|---|
| CA-01 | HU-08 | Al tocar la pieza en el catálogo se abre su detalle con descripción y precio | Se abrió el detalle con nombre, descripción y $580.32 | Pasa | 125 |
| CA-02 | HU-08 | Se pueden deslizar todas las fotos de la galería | Se deslizaron las 6 fotos hasta la última | Pasa | 125 |
| CA-03 | HU-09 | La pieza agregada aparece en el carrito | La pieza aparece en Tu carrito | Pasa | 123, 126 |
| CA-04 | HU-09 | Al cambiar la cantidad el total se actualiza | Con 2 piezas el total es $1,160.64 | Pasa | 123, 126 |
| CA-05 | HU-09 | Al quitar la pieza sale del carrito | Carrito vacío en la app y en el servidor | Pasa | 129 |
| CA-06 | HU-09 | El carrito de la app coincide con el del sitio web | El sitio web muestra la misma pieza ×2 y $1,160.64 | Pasa | 124 |
| CA-07 | HU-10 | La pieza marcada como favorita aparece en Favoritos | "1 pieza guardada" con la pieza | Pasa | 128 |
| CA-08 | HU-10 | La favorita también aparece en el sitio web | Mis favoritos del sitio web muestra la pieza (1 pieza, $580.32) | Pasa | 127 |
| CA-09 | HU-10 | Al quitarla desaparece de Favoritos | Ya no está en la app ni en el servidor | Pasa | 129 |

**Resultado:** 9 de 9 casos pasan. Se cumplen los criterios de aceptación de HU-08, HU-09 y HU-10.

Estado inicial de la cuenta en el sitio web (carrito y favoritos vacíos): evidencias 121 y 122. Resultado completo de la ejecución: evidencia 129.

## Cómo ejecutarla

```
flutter test integration_test/aceptacion_test.dart --dart-define-from-file=env.json
```

Con `--dart-define=PAUSA_WEB=40` se detiene 40 s en CA-06 y CA-08 para tomar la captura del sitio web.
