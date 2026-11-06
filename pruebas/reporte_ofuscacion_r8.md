# Reporte de ofuscación y descompilación #275 · R8, ProGuard y `--obfuscate`

**Tarea:** #275 · **Fecha:** 6 de noviembre de 2026 · **Herramienta:** JADX 1.5.1

**Criterio de aceptación:** el APK de producción compila y funciona; el reporte muestra nombres ofuscados.

## Qué se configuró

| Parte del APK | Qué la protege | Dónde |
|---|---|---|
| Código Java/Kotlin (Firebase, plugins, motor de Flutter) | R8: `isMinifyEnabled = true`, `isShrinkResources = true`, `proguard-android-optimize.txt` + `proguard-rules.pro` | `android/app/build.gradle.kts` |
| Código Dart de la app (pantallas, servicios, modelos), compilado a `lib/<abi>/libapp.so` | `--obfuscate --split-debug-info=build/simbolos` | `.github/workflows/release-apk.yml` (ya estaba) |

Las reglas de `proguard-rules.pro` son pocas a propósito: Flutter y los plugins de Firebase ya traen las suyas (consumer rules) para lo que el código nativo y el manifest llaman por nombre. Solo se agregó `-dontwarn` para Play Core, que la app no usa, y se conservan archivo y línea para los reportes de Crashlytics. Una primera versión con `-keep` amplios para Flutter y Firebase dejaba más clases sin ofuscar y se descartó.

Para leer un error de un APK ofuscado se usan `build/app/outputs/mapping/release/mapping.txt` (Java) y los símbolos de `build/simbolos` (Dart, con `flutter symbolize`).

## Antes y después (APK arm64-v8a de release)

**Antes:** build de release sin `--obfuscate` y sin configuración explícita. Flutter ya aplicaba R8 por defecto al código Java, pero el código Dart conservaba sus nombres.

| Dato | Antes | Después |
|---|---|---|
| Tamaño del APK | 20.5 MB | 19.4 MB |
| `libapp.so` (código Dart) | 6.9 MB | 5.8 MB |
| Clases Java que recupera JADX | 2054 | 2120 |
| Clases con nombre de 1 o 2 letras (`a`, `ky`, `n1`…) | 1055 | 1065 |
| `AuthService` en `libapp.so` | 3 apariciones | 0 |
| `PerfilService` | 2 | 0 |
| `NotificacionesService` | 1 | 0 |
| `CertificadoFijado` (pinning, #272) | 1 | 0 |
| `renovarToken` (#272) | 1 | 0 |
| `eliminarCuenta` (#273) | 2 | 0 |

Con JADX, la lógica de la app no aparece como Java en ningún caso, porque Flutter compila Dart a código nativo. Lo que se podía leer eran los nombres de las clases y funciones dentro de `libapp.so`, y después de `--obfuscate` ya no están. En el código Java, los paquetes como `io.flutter.plugins.firebase.messaging` conservan las clases que el manifest declara por nombre, como `FlutterFirebaseMessagingService`. El resto queda como `a`, con campos `a`, `b`, `c` y referencias a `defpackage.ky`, `defpackage.n1`, etc. (evidencia 211b).

## Prueba del APK ofuscado en el Moto G6 Plus (Android 9)

| Caso | Resultado | Evidencia |
|---|---|---|
| CA-55 | La app abre sin errores; logcat sin `FATAL EXCEPTION` | 211 |
| CA-56 | Catálogo con productos e imágenes del servidor; el pinning de certificados (#272) funciona | 211a |
| CA-57 | Inicio de sesión con Firebase; el teléfono actualiza su registro para avisos en la base | 211c |
| CA-58 | Llega un aviso push enviado por el backend (`enviarAUsuario`) | 211d |

**4 de 4 casos pasan.** El APK de producción compila y funciona con R8 y la ofuscación de Dart.
