# Herramientas y pipelines de pruebas (app móvil)

Revisión del plan de pruebas (#177). Todas las pruebas se automatizan con GitHub Actions y
cada tipo de prueba tiene su propio pipeline en `.github/workflows`.

## Herramientas

| Prueba | Herramienta | Orientada a móvil | Por qué se eligió |
|---|---|---|---|
| Unitarias y de widgets | `flutter_test` | Sí | Viene con Flutter; prueba la lógica y las pantallas sin abrir un teléfono, en segundos. |
| Análisis de código estático | `flutter analyze` con `flutter_lints` y `gitleaks` | Sí | Es el analizador oficial de Dart/Flutter; `gitleaks` revisa que no haya claves en el código. |
| Integración | `integration_test` en un emulador Android (API 34) con `android-emulator-runner` | Sí | Instala la app real en Android y la conecta con el backend, igual que la usa un cliente. |
| Aceptación | `integration_test` en el emulador Android | Sí | Recorre cada criterio de aceptación de las historias de usuario en la app instalada. |
| Regresión | `flutter_test` + `integration_test` en el emulador | Sí | Vuelve a correr todas las pruebas y las de la versión anterior para ver que nada se rompió. |
| Rendimiento | `FrameTiming` en el emulador y `flutter build apk --analyze-size` | Sí | Mide tiempos de carga, cuadros lentos y el peso del APK. |
| Esfuerzo | k6 (Grafana) | No: prueba el backend | La app no guarda datos propios; lo que debe aguantar muchos usuarios a la vez es el backend que usa. Un teléfono no puede generar esa carga. |

### Cambios respecto a lo planeado

| Prueba | Planeado | Usado | Motivo |
|---|---|---|---|
| Rendimiento | `watchPerformance` de `integration_test` | `FrameTiming` | `watchPerformance` necesita el servicio de depuración de Flutter, que no está disponible en el emulador de GitHub Actions. `FrameTiming` mide los mismos tiempos de cuadro sin depender de él. |
| Aceptación | Dentro del pipeline de integración | Pipeline propio (`pruebas-aceptacion.yml`) | Para que cada tipo de prueba tenga su pipeline y su resultado por separado. |
| Esfuerzo | Solo a mano | A mano y al publicar una etiqueta `v*` | Para que quede ligada al versionamiento: cada versión se prueba bajo carga. |

Las demás herramientas se mantienen como se planearon.

## Pipelines y versionamiento

Usamos Git Flow: cada tarea en una rama `feature/*` (o `test/*`, `fix/*`), que se une a `develop`
por Pull Request; al cerrar el sprint, `develop` se une a `main` y se publica una etiqueta `v*`.

| Momento del versionamiento | Pipelines que corren |
|---|---|
| Pull Request de una rama de tarea a `develop` | `flutter-ci.yml`, `analisis-estatico.yml`, `pruebas-unitarias.yml` |
| Push a `develop` (al unir el Pull Request) | `flutter-ci.yml`, `analisis-estatico.yml`, `pruebas-unitarias.yml` |
| Pull Request de `develop` a `main` | Los anteriores + `pruebas-integracion.yml` y `pruebas-aceptacion.yml` |
| Push a `main` | `flutter-ci.yml`, `pruebas-regresion.yml` |
| Etiqueta de versión `v*` | `pruebas-regresion.yml`, `pruebas-rendimiento.yml`, `pruebas-esfuerzo.yml` |
| Versión publicada en Releases | `release-apk.yml` (pruebas + APK) |
| Cada lunes | `pruebas-regresion.yml` |
| A mano (Actions → Run workflow) | Todos excepto `flutter-ci.yml` |

Las pruebas rápidas (estático y unitarias) corren en cada cambio. Las que usan el emulador o el
backend real (integración, aceptación, regresión, rendimiento y esfuerzo) corren antes y después
de unir a `main`, que es cuando se arma una versión.
