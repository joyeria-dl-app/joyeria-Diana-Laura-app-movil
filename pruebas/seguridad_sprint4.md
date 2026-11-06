# Pruebas de seguridad · Sprint 4 (HU-19, tarea #99)

- **Qué se analizó:** el APK de producción firmado con la llave de subida (`app-release.apk`, versión `0.3.0+3`, con HU-14 a HU-17 integradas)
- **Herramientas:** `aapt2` (permisos y manifiesto final), `apksigner` (firma), búsqueda de secretos dentro del APK, emulador con root, `test/seguridad_test.dart` y `test/root_test.dart`
- **Fecha:** 4 de noviembre de 2026

MobSF no se pudo ejecutar en la computadora del equipo. Las revisiones de manifiesto, permisos, firma y secretos que hace MobSF se hicieron con las herramientas oficiales del SDK de Android sobre el mismo APK.

## Permisos del APK

El manifiesto final (el de la app más el de cada librería) pide 7 permisos. Todos se usan:

| Permiso | Nivel | Para qué lo usa la app |
|---|---|---|
| `INTERNET` | Normal | Conectarse al backend y a Firebase |
| `ACCESS_NETWORK_STATE` | Normal | Firebase y la caché de fotos saben si hay conexión |
| `POST_NOTIFICATIONS` | Peligroso (se pide al usuario) | Avisos del estado del pedido (HU-15) |
| `WAKE_LOCK` | Normal | Firebase Cloud Messaging recibe el aviso con la pantalla apagada |
| `VIBRATE` | Normal | El aviso del pedido vibra al llegar |
| `com.google.android.c2dm.permission.RECEIVE` | Normal | Recibir mensajes de Firebase Cloud Messaging |
| `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Firma | Lo agrega AndroidX para que sus receptores internos no se puedan llamar desde otras apps |

No pide cámara, almacenamiento, ubicación, contactos, micrófono ni teléfono. La foto del perfil se elige con el selector de fotos del sistema, que no necesita permiso.

## Revisión del APK

| # | Revisión | Cómo | Resultado |
|---|---|---|---|
| S4-01 | Solo pide los permisos que usa | `aapt2 dump permissions` y prueba automatizada | Pasa |
| S4-02 | Firmado con la llave de subida, no con la de depuración | `apksigner verify --print-certs` (esquema v2; minSdk 24 no necesita v1) | Pasa |
| S4-03 | No es depurable | `aapt2 dump badging` (sin `application-debuggable`) y prueba automatizada | Pasa |
| S4-04 | No permite respaldos de los datos | Manifiesto final: `allowBackup=false` y `fullBackupContent=false` | Pasa |
| S4-05 | Sin tráfico HTTP sin cifrar | Sin `usesCleartextTraffic`; con `targetSdk 36` Android lo bloquea por defecto | Pasa |
| S4-06 | Componentes exportados protegidos | 1 pantalla (la principal) y 3 receptores; cada receptor exige un permiso del sistema (`c2dm.permission.SEND` o `DUMP`) | Pasa |
| S4-07 | El enlace `joyeriadl://pago` no da por pagado un pedido | Solo acepta `tipo` pedido o apartado e `id` numérico; el estado real lo decide el servidor (revisado en `seguridad_pago_sprint3.md`) | Pasa |
| S4-08 | Las cuentas de prueba no van dentro del APK | Búsqueda de los 6 valores de `env.json` dentro del APK: ninguno aparece | Pasa |
| S4-09 | La llave de subida no está en el repositorio | `key.properties`, `*.jks` y `*.keystore` ignorados y sin versionar; prueba automatizada | Pasa |
| S4-10 | Crashlytics no reporta errores de desarrollo | Recolección activa solo con `kReleaseMode`; prueba automatizada | Pasa |

## Teléfonos con root (caso agregado el 11 de octubre de 2026)

Con root el cifrado del Keystore protege menos y el APK se puede modificar con más facilidad. La defensa principal no cambia: el servidor valida monto y estado del pago (#98). La app agrega una capa más:

| # | Revisión | Cómo | Resultado |
|---|---|---|---|
| R-01 | Detecta root al abrir la app | `MainActivity.kt` (canal `joyeria/dispositivo`): programa `su` en rutas del sistema, compilación `test-keys` o `userdebug`/`eng`, o apps de root (Magisk, SuperSU) | Pasa en emulador con root |
| R-02 | Avisa al usuario en todas las pantallas | Franja roja arriba (`AvisoRoot`); el catálogo se sigue navegando | Pasa (evidencias 157 y 157a) |
| R-03 | No guarda la sesión en el teléfono | Con root se usa `MemorySessionStorage`: la sesión vive solo mientras la app está abierta | Pasa (prueba automatizada) |
| R-04 | No deja pagar con Mercado Pago | `abrirPagoMercadoPago` no pide la preferencia ni abre el navegador; avisa que se puede pagar en la tienda | Pasa (prueba automatizada) |
| R-05 | Si la detección falla, la app sigue normal | Error del canal → sin root | Pasa (prueba automatizada) |
| R-06 | APK de producción ofuscado | `--obfuscate --split-debug-info` en el pipeline Publicar APK; los símbolos se guardan como artefacto (90 días) para leer los errores de Crashlytics | Pasa: nombres como `SecureSessionStorage` o `abrirPagoMercadoPago` ya no aparecen en `libapp.so` |

Se intentó primero con el paquete `flutter_jailbreak_detection`, pero está sin mantenimiento y no compila con el Android Gradle Plugin actual; por eso la detección se escribió en Kotlin, sin dependencias.

**Emulador con root:** imagen `android-35 google_apis x86_64` (sin Play Store), AVD `Root_35`. `su 0 id` devuelve `uid=0(root)` y `ro.build.type` es `userdebug` (evidencia 157b). En el emulador normal (`google_apis_playstore`, tipo `user`) no aparece el aviso.

## Sesión ante un 401 y Certificate Pinning (#272, 5 de noviembre de 2026)

**Renovación de la sesión.** Al iniciar sesión la app guarda, en el almacenamiento cifrado del teléfono, el `refreshToken` que entrega Firebase. Si el backend responde **401** (token vencido o revocado), el interceptor de Dio pide a Firebase un ID token nuevo (`securetoken.googleapis.com/v1/token`), vuelve a entrar con `POST /auth/login/movil` y repite la petición una sola vez. Si varias peticiones reciben 401 juntas, comparten la misma renovación. Si no se puede renovar (sin `refreshToken`, cuenta deshabilitada o Firebase lo rechaza), se borra la sesión y la app lleva a iniciar sesión. Un 401 de `/auth/login` (contraseña incorrecta) no intenta renovar.

**Certificate Pinning.** El certificado de `onrender.com` lo firma Google Trust Services (WE1 → GTS Root R4, con versión cruzada firmada por GlobalSign Root CA) y Render lo renueva cada ~90 días (el actual vence el 20 de diciembre de 2026). Fijar ese certificado haría que la app dejara de conectarse en cada renovación, así que se fijan las **autoridades raíz**: el cliente HTTP de la app usa un `SecurityContext` sin las autoridades del teléfono y solo con estas dos, y antes de usarlas comprueba su huella SHA-256:

| Autoridad | SHA-256 | Vence |
|---|---|---|
| GTS Root R4 | `349dfa4058c5e263123b398ae795573c4e1313c83fe68f93556cd5e8031b3c7d` | 2036 |
| GlobalSign Root CA | `ebd41040e4bb3ec742c9e381d31ef2a41a48b6685c96e7cef3c1df6cd4331c99` | 2028 |

Un certificado de otra autoridad (un proxy que intercepta el tráfico o una CA instalada en el teléfono) se rechaza. Si el texto de un certificado fijado se altera, su huella deja de coincidir y la app no confía en ninguno.

**Pruebas** (`test/sesion_seguridad_test.dart`, 11 casos, evidencia 196): renovación sin que se note, una sola renovación para varias peticiones, sesión borrada cuando no se puede renovar, sin renovar en el login, `refreshToken` guardado al iniciar sesión, huellas correctas, certificado alterado, **certificado válido de otra autoridad (github.com, Sectigo) rechazado** (con un cliente de control sin pinning que sí se conecta) y conexión aceptada al backend real de Render. Además, la prueba de aceptación de perfil y zonas pasó 8 de 8 en el emulador con el cliente fijado contra Render. Con estos cambios pasan 388 pruebas.

**Mantenimiento.** Si Render cambia de autoridad, la app dejaría de conectarse; la prueba "El cliente de la app sí se conecta al backend real de Render" falla en el pipeline antes de publicar una versión. GlobalSign Root CA vence en enero de 2028: antes hay que revisar la cadena de Render y actualizar la lista.

## Observación

La clave de Firebase (`FIREBASE_API_KEY`) sí está dentro del APK porque la app la necesita para iniciar sesión. Igual que en el Sprint 2, Firebase la trata como un identificador público del proyecto; se recomienda mantener sus restricciones por aplicación y por API en la consola de Google Cloud.

## Pruebas automatizadas nuevas

En `test/seguridad_test.dart`, grupo **Build final (Sprint 4)**: permisos peligrosos, componentes exportados y depuración, llave fuera del repositorio, firma de producción y Crashlytics solo en producción. En `test/root_test.dart`: detección, aviso, pago bloqueado y sesión solo en memoria. Con ellas: 374 pruebas pasan y `flutter analyze` no marca problemas.

## Cómo repetir el análisis

```bash
flutter build apk --release --dart-define-from-file=env.json
aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
flutter test test/seguridad_test.dart
```
