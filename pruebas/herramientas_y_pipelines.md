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
| CA-15 Mis apartados (aceptación HU-11) | Sin apartados activos se espera "No tienes apartados" | Tres casos: sin apartados, solo cancelados o liquidados, y con activos | Al unir el Pull Request #192, la cuenta de aceptación quedó solo con apartados cancelados por las pruebas de la HU-12; la app los muestra en la lista (correcto) y la prueba esperaba el aviso de vacío (#193). |
| Esfuerzo: rutas y límite por IP | Catálogo y detalle, sin sesión | Catálogo, detalle, carrito, pedidos y apartados con sesión; escenario de 50 usuarios y escenario de subida por escalones hasta 150; durante la prueba se sube el límite por IP en Render | El backend limita a 500 peticiones por IP cada 15 minutos y toda la carga de k6 sale de una sola máquina: sin subirlo, la prueba medía los rechazos 429 y no la capacidad. Se sube solo durante la prueba y se regresa a 500 (#149). |

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
| Versión publicada en Releases | `release-apk.yml`, que primero llama a `pruebas-regresion.yml` | En secuencia: regresión completa y, solo si pasa, el APK | No se genera el APK y se abre una issue |
| Programada | Regresión cada lunes sobre `develop` | Unitarias y, si pasan, integración (en secuencia) | `avisar-fallas.yml` abre una issue con el enlace a la corrida |
| Cualquier workflow termina en rojo en `develop`, `main` o una etiqueta | `avisar-fallas.yml` | Se dispara al terminar el workflow | Abre una issue o comenta la que ya está abierta para ese workflow |

## Paralelo o secuencia

- **Entre workflows: en paralelo.** Cada workflow corre en su propio runner (máquina virtual de GitHub con `ubuntu-24.04`). Los del emulador usan una cuenta de prueba distinta cada uno para no cambiarse el carrito (#185).
- **Misma cuenta: en secuencia.** Dos corridas del mismo workflow, o integración y regresión, pueden usar la misma cuenta a la vez (por ejemplo, al unir un PR a `develop` mientras otro PR hacia `main` corre sus pruebas). Cada trabajo que inicia sesión tiene un grupo `concurrency` por cuenta (`cuenta-pruebas` para integración, regresión y esfuerzo en producción; `cuenta-aceptacion` y `cuenta-entorno`) sin cancelar la corrida en curso: la segunda espera a que termine la primera. Si llega una tercera mientras otra espera, GitHub deja solo la más reciente en espera y cancela la anterior pendiente (#238).
- **Dentro de un workflow: en secuencia.** Cada paso espera al anterior; si uno falla, los siguientes no corren. Excepción: Pruebas de rendimiento tiene dos trabajos independientes (tamaño del APK y tiempos) que corren en paralelo.
- **Trabajos encadenados:** Regresión corre integración solo si pasaron las unitarias (`needs: unitarias`) y Publicar APK compila solo si pasó la regresión (`needs: regresion`).
- **Dentro de las pruebas:** `flutter test` reparte los archivos de pruebas unitarias en paralelo entre los núcleos del runner; las pruebas del emulador corren una tras otra en el mismo emulador.

Cada archivo `.yml` explica al inicio su tipo de prueba, su alcance, cómo se ejecuta y qué hace según el resultado, y cada paso tiene un comentario.

## Revisión del Sprint 3 (observaciones, #206)

| Observación | Cambio |
|---|---|
| Comentar los yml | Los 11 workflows tienen un encabezado (tipo, alcance, ejecución y acción según el resultado) y un comentario en cada paso. |
| ¿Las pruebas se ejecutan en paralelo o en secuencia? | Se indica en cada workflow y se resume en la sección anterior. |
| Atender los comentarios de los resultados de las pruebas automatizadas | La regresión programada del 12 de octubre (run 38314303514) falló porque `git describe` no encontraba la etiqueta de la versión anterior en `develop`; las 255 pruebas unitarias sí pasaron. Ahora se toma la etiqueta `v*` más alta del repositorio; las 134 pruebas de v0.2.0 pasan contra el código actual. El resumen del análisis estático decía "sin problemas" aunque fallara; ahora muestra el resultado real de cada revisión. |
| Que los pipelines actúen según el resultado | Publicar APK corre la regresión completa y solo compila si pasa. `avisar-fallas.yml` abre una issue cuando un workflow falla en `develop`, `main` o una etiqueta (GitHub lo activa cuando el archivo llega a `main`, con la v0.3.0). En los PR, los checks obligatorios bloquean el merge. |

## Carpetas con los elementos de cada prueba

| Carpeta | Qué contiene |
|---|---|
| `analysis_options.yaml` | Reglas del análisis estático (`flutter_lints`) |
| `test/` | Pruebas unitarias y de widgets, con sus datos simulados |
| `integration_test/` | Integración, aceptación (`aceptacion_test.dart` y `aceptacion_pedidos_test.dart`) rendimiento (`rendimiento_test.dart`) y entorno (`entorno_test.dart`) en el emulador; `aceptacion_pago_test.dart` es la aceptación del pago con Mercado Pago; `sesion.dart` tiene el inicio de sesión que comparten |
| `pruebas/esfuerzo/` | Script de k6 con la carga (50 usuarios) y los umbrales (95 % < 2 s, < 1 % de errores) |
| `pruebas/entorno.sh` | Corre la prueba de entorno y aplica con `adb` la batería baja, la llamada, el segundo plano y el modo avión |
| `pruebas/*.md` | Resultados de aceptación, seguridad, regresión, entorno y esfuerzo de cada sprint |
| Secretos del repositorio | Cuenta de cliente de prueba y clave de Firebase que usan los pipelines |
