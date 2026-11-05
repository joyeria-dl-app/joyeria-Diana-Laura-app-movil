# Pruebas de seguridad · Sprint 4 (HU-19, tarea #99)

- **Qué se analizó:** el APK de producción firmado con la llave de subida (`app-release.apk`, versión `0.3.0+3`, con HU-14 a HU-17 integradas)
- **Herramientas:** `aapt2` (permisos y manifiesto final), `apksigner` (firma), búsqueda de secretos dentro del APK y `test/seguridad_test.dart`
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

## Observación

La clave de Firebase (`FIREBASE_API_KEY`) sí está dentro del APK porque la app la necesita para iniciar sesión. Igual que en el Sprint 2, Firebase la trata como un identificador público del proyecto; se recomienda mantener sus restricciones por aplicación y por API en la consola de Google Cloud.

## Pruebas automatizadas nuevas

En `test/seguridad_test.dart`, grupo **Build final (Sprint 4)**: permisos peligrosos, componentes exportados y depuración, llave fuera del repositorio, firma de producción y Crashlytics solo en producción. Con ellas: 367 pruebas pasan y `flutter analyze` no marca problemas.

## Cómo repetir el análisis

```bash
flutter build apk --release --dart-define-from-file=env.json
aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
flutter test test/seguridad_test.dart
```
