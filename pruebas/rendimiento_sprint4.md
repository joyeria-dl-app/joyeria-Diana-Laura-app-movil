# Pruebas de rendimiento · Sprint 4 (build de producción, HU-17)

**Tarea:** #154 · **Fecha:** 5 de noviembre de 2026 · **Pipeline:** `.github/workflows/pruebas-rendimiento.yml` · **Prueba:** `integration_test/rendimiento_test.dart`

**Criterio de aceptación:** APK menor a 30 MB, arranque menor a 3 s y sin cuadros perdidos notables.

## Resultado

| Métrica | Umbral | Línea base (17 oct) | Sprint 4 | Cómo se midió | Resultado |
|---|---|---|---|---|---|
| APK arm64 (el que se instala en un teléfono) | < 30 MB | 19.3 MB | **19.5 MB** | `flutter build apk --release --split-per-abi` | Pasa |
| Arranque en frío del APK de producción | < 3 s | — | **1.79 s** (mediana de 10) | `am start -W` en el emulador Pixel 8, APK x86_64 de producción | Pasa |
| Arranque de la app (pipeline) | < 3 s | 1.70 s | **1.02 s** | Prueba en el emulador del pipeline | Pasa |
| Carga del catálogo | < 2 s | 1.76 s | **1.30 s** | Pipeline | Pasa |
| Carga del detalle | < 3 s | 0.69 s | **0.67 s** | Pipeline | Pasa |
| Cuadros perdidos en el scroll | < 25 % | 13.7 % | **8.6 %** (18 de 210) | Pipeline, tiempos de cuadro de Flutter | Pasa |

Corrida del pipeline: [42090042984](https://github.com/joyeria-dl-app/joyeria-Diana-Laura-app-movil/actions/runs/42090042984) (tamaño, tiempos y comparación con la línea base en verde).

### Detalle

- **Tamaños de producción:** APK arm64 19.5 MB, armeabi-v7a 17.2 MB, x86_64 20.9 MB. El APK con las tres arquitecturas pesa 54.4 MB y el AAB 53.6 MB; Google Play entrega a cada teléfono solo la parte de su arquitectura, por lo que el tamaño que cuenta es el del APK arm64.
- **Arranque en frío (10 corridas):** 3460, 2389, 1773, 1747, 1771, 1988, 1797, 1783, 1696 y 2890 ms; mínimo 1.70 s, mediana 1.79 s y promedio 2.13 s. La primera corrida es la más lenta porque Android prepara la app recién instalada.
- **Memoria:** 106 MB (PSS) en el APK de producción con el Inicio abierto. Los 472 MB que reporta el pipeline son del modo debug e incluyen las herramientas de depuración (informativo).
- **Fluidez:** `dumpsys gfxinfo` no registra los cuadros de Flutter (dibuja con su propio motor), por eso la fluidez se mide con los tiempos de cuadro que da Flutter en la prueba del pipeline. Un cuadro se pierde si tarda más de 16 ms en construirse.

## Error encontrado y corregido

Desde el catálogo por secciones (#254) la prueba de rendimiento fallaba en `develop`: después del scroll no encontraba ninguna tarjeta para abrir el detalle. La causa: al desplazarse, las secciones que salían de la pantalla se destruían y, al volver, se reconstruían vacías y **volvían a pedir sus piezas al servidor**. Eso también hacía peticiones de más en el uso normal.

- `lib/screens/catalogo_screen.dart`: las secciones ya cargadas se conservan (`AutomaticKeepAliveClientMixin`); ya no se piden otra vez al subir y bajar.
- `integration_test/rendimiento_test.dart`: espera a que haya tarjetas antes de abrir el detalle.

Con el cambio, el pipeline vuelve a pasar y los cuadros perdidos bajaron de 13.7 % (línea base) a 8.6 %.
