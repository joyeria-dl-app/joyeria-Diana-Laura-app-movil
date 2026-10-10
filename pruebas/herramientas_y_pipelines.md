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
| Entorno | `integration_test` en el emulador + `adb` (`pruebas/entorno.sh`) | Sí | `adb` cambia la batería, simula una llamada, manda la app a segundo plano y activa el modo avión en el emulador mientras la prueba revisa cómo reacciona la app. |
| Esfuerzo | k6 (Grafana) | No: prueba el backend | La app no guarda datos propios; lo que debe aguantar muchos usuarios a la vez es el backend que usa. Un teléfono no puede generar esa carga. |

### Cambios respecto a lo planeado

| Prueba | Planeado | Usado | Motivo |
|---|---|---|---|
| Rendimiento | `watchPerformance` de `integration_test` | `FrameTiming` | `watchPerformance` necesita el servicio de depuración de Flutter, que no está disponible en el emulador de GitHub Actions. `FrameTiming` mide los mismos tiempos de cuadro sin depender de él. |
| Aceptación | Dentro del pipeline de integración | Pipeline propio (`pruebas-aceptacion.yml`) | Para que cada tipo de prueba tenga su pipeline y su resultado por separado. |
| Esfuerzo | Solo a mano | A mano y al publicar una etiqueta `v*` | Para que quede ligada al versionamiento: cada versión se prueba bajo carga. |
| Integración, aceptación y rendimiento | Solo al cerrar el sprint | También en cada unión a `develop` | Para no dejar las pruebas al final del sprint: una falla se detecta el mismo día que se une la tarea. |
| Cuenta de cliente de prueba | Una sola para todos los pipelines | Una para integración y regresión, otra para aceptación y otra para entorno | Al unir el Pull Request #184 a develop, aceptación e integración fallaron porque corrían al mismo tiempo que entorno con la misma cuenta y se cambiaban el carrito entre ellos; corridos por separado pasaron (#185). |
| Inicio de sesión en las pruebas del emulador | Cada prueba con su propio bloque | Función compartida `iniciarSesion()` (`integration_test/sesion.dart`) | Al unir el Pull Request #188, aceptación falló porque el toque en "Iniciar sesión" no le atinó al botón mientras la pantalla seguía en animación o el teclado lo tapaba. La función espera la animación, cierra el teclado, hace visible el botón y reintenta hasta 3 veces (#189). |
| Aceptación del pago con Mercado Pago (HU-12) | Automática en el pipeline | En el emulador, con un paso a mano: la persona que prueba paga en la página de Mercado Pago con el comprador de prueba (`integration_test/aceptacion_pago_test.dart`) | Mercado Pago no permite automatizar su página de pago, y solo procesa pagos cuando vendedor y comprador son cuentas de prueba. La prueba avisa con "ACEPTACION PASO" qué hacer y revisa en la app y en el servidor el resultado (#44). |

Las demás herramientas se mantienen como se planearon.

## Pipelines y versionamiento

Usamos Git Flow: cada tarea en una rama `feature/*` (o `test/*`, `fix/*`) que se une a `develop`
por Pull Request; al cerrar el sprint, `develop` se une a `main` y se publica una etiqueta `v*`.
Las pruebas no se dejan para el final: cada tarea que se une a `develop` pasa ese mismo día por
integración, aceptación y rendimiento en el emulador.

| Momento | Pipelines | Orden | Si falla |
|---|---|---|---|
| Pull Request de una tarea a `develop` | `flutter-ci.yml`, `analisis-estatico.yml`, `pruebas-unitarias.yml` | En paralelo | No se puede unir el Pull Request |
| Push a `develop` (tarea ya unida) | Los anteriores + `pruebas-integracion.yml`, `pruebas-aceptacion.yml`, `pruebas-rendimiento.yml`, `pruebas-entorno.yml` | En paralelo, después de que pasaron los del Pull Request | Se corrige con una tarea `fix/*` antes de seguir |
| Pull Request de `develop` a `main` | `flutter-ci.yml`, `analisis-estatico.yml`, `pruebas-unitarias.yml`, `pruebas-integracion.yml`, `pruebas-aceptacion.yml`, `pruebas-entorno.yml` | En paralelo | No se puede pasar a `main` |
| Push a `main` y etiqueta `v*` | `pruebas-regresion.yml`, `pruebas-rendimiento.yml`, `pruebas-esfuerzo.yml` | En paralelo | Se corrige antes de publicar la versión |
| Versión publicada en Releases | `release-apk.yml` | Pruebas y después el APK | No se genera el APK |
| Programada | Regresión cada lunes | | Se abre una tarea en el tablero |

## Carpetas con los elementos de cada prueba

| Carpeta | Qué contiene |
|---|---|
| `analysis_options.yaml` | Reglas del análisis estático (`flutter_lints`) |
| `test/` | Pruebas unitarias y de widgets, con sus datos simulados |
| `integration_test/` | Integración, aceptación (`aceptacion_test.dart` y `aceptacion_pedidos_test.dart`) rendimiento (`rendimiento_test.dart`) y entorno (`entorno_test.dart`) en el emulador; `aceptacion_pago_test.dart` es la aceptación del pago con Mercado Pago; `sesion.dart` tiene el inicio de sesión que comparten |
| `pruebas/esfuerzo/` | Script de k6 con la carga (50 usuarios) y los umbrales (95 % < 2 s, < 1 % de errores) |
| `pruebas/entorno.sh` | Corre la prueba de entorno y aplica con `adb` la batería baja, la llamada, el segundo plano y el modo avión |
| `pruebas/*.md` | Resultados de aceptación, seguridad, regresión y entorno de cada sprint |
| Secretos del repositorio | Cuenta de cliente de prueba y clave de Firebase que usan los pipelines |
