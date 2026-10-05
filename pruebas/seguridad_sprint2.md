# Pruebas de seguridad · Sprint 2 (HU-19, tarea #97)

- **Prueba automatizada:** `test/seguridad_test.dart` (corre con las pruebas unitarias)
- **Revisión del historial:** gitleaks en el pipeline `.github/workflows/analisis-estatico.yml`
- **Fecha:** 5 de octubre de 2026

## Qué se revisó

| # | Revisión | Cómo | Resultado |
|---|---|---|---|
| S-01 | El token y el usuario se guardan con `flutter_secure_storage` (cifrado con el almacén de claves de Android) | Prueba automatizada | Pasa |
| S-02 | Al cerrar sesión no queda ningún dato guardado | Prueba automatizada | Pasa |
| S-03 | La app no usa almacenamiento sin cifrar (`shared_preferences`) | Prueba automatizada | Pasa |
| S-04 | Ningún archivo de la app contiene una clave de Firebase | Prueba automatizada (busca el patrón `AIza…`) | Pasa |
| S-05 | La clave de Firebase y la cuenta de prueba se leen al compilar (`String.fromEnvironment`), no están escritas | Prueba automatizada | Pasa |
| S-06 | `env.json` está ignorado por Git y `env.example.json` no trae valores reales | Prueba automatizada | Pasa |
| S-07 | La clave de Firebase, el correo y la contraseña de prueba no aparecen en ningún archivo versionado ni en ningún commit del historial | Búsqueda de los valores reales en todo el historial (`git log --all -S`) y gitleaks en el pipeline | Pasa |
| S-08 | La sesión no se copia en los respaldos del teléfono | Prueba automatizada sobre `AndroidManifest.xml` | **Fallaba → corregido** |
| S-09 | La app solo se conecta por HTTPS | Prueba automatizada | Pasa |

## Hallazgo corregido

**S-08.** El manifiesto de Android no indicaba `allowBackup`, y Android lo trata como activado: los datos de la app, incluida la sesión, podían copiarse en los respaldos del teléfono. Se agregó `android:allowBackup="false"` y `android:fullBackupContent="false"`. La prueba falló antes del cambio y pasa después.

## Observación

La clave de Firebase se incluye en el APK al compilar (es necesaria para iniciar sesión). Firebase la trata como un identificador público del proyecto: no da acceso por sí sola. Se recomienda mantener activas las restricciones de la clave (por aplicación y por API) en la consola de Google Cloud.

## Cómo ejecutarla

```
flutter test test/seguridad_test.dart
```
