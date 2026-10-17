# Despliegue de la app móvil vía Google Play

**Tarea:** #210 · Observación: "Se recomienda revisar la forma de despliegue vía Google Play, especificando la versión".

## Cómo se despliega hoy (Sprints 1 a 3)

Al cerrar cada sprint, `develop` se une a `main`, se crea la etiqueta de versión y se publica en **GitHub Releases**. El workflow **Publicar APK** corre la regresión completa y, solo si pasa, compila el APK de producción y lo adjunta a la versión. Quien prueba la app la descarga de ahí y la instala en su teléfono.

| Versión | Sprint | Fecha | Canal | Archivo |
|---|---|---|---|---|
| v0.1.0 | Sprint 1 | 27 sep 2026 | GitHub Releases | APK |
| v0.2.0 | Sprint 2 | 5 oct 2026 | GitHub Releases | `joyeria-diana-laura-v0.2.0.apk` |
| v0.3.0 | Sprint 3 | 26 oct 2026 (#92) | GitHub Releases | `joyeria-diana-laura-v0.3.0.apk` |

## Cómo se desplegará con Google Play (Sprint 4, HU-17)

Google Play no acepta APK firmados con la llave de depuración: pide un **Android App Bundle (AAB)** firmado con una llave de subida propia. El paso a Google Play queda en la HU-17 (#61):

| Paso | Tarea | Qué se hace |
|---|---|---|
| 1. Firma | #62 | Crear la llave de subida (`upload-keystore.jks`). La llave y sus contraseñas van en los secretos del repositorio, nunca en el código; `android/app/build.gradle.kts` deja de firmar con la llave de depuración. Google guarda la llave final (Play App Signing). |
| 2. Build | #63 | `flutter build appbundle --release` genera el AAB firmado. |
| 3. Pruebas internas | #64 | Subir el AAB al canal **Pruebas internas** de Google Play Console; los testers (el equipo y la maestra) instalan la app desde Google Play con un enlace de invitación. |
| 4. Errores | #65 | Firebase Crashlytics reporta los cierres inesperados de la versión instalada. |
| 5. Versión final | #93 | v1.0.0: develop se une a main, se publica en GitHub Releases y el mismo AAB se sube a Google Play. |

### Canales de Google Play

| Canal | Para qué | Quién la instala | Uso en el proyecto |
|---|---|---|---|
| Pruebas internas | Probar la versión en teléfonos reales en minutos, sin revisión larga de Google | Hasta 100 testers invitados por correo | v1.0.0 (Sprint 4) |
| Pruebas cerradas | Probar con un grupo mayor; Google la revisa | Lista de testers o grupos | Si la tienda quiere probar con clientes |
| Producción | Publicar para todos | Cualquier usuario de Google Play | Fuera del alcance del cuatrimestre; requiere la cuenta de desarrollador de la tienda |

Una versión solo avanza de canal (internas → cerradas → producción) si pasó en el canal anterior.

## Numeración de versiones

La versión está en `pubspec.yaml` con la forma `versionName+versionCode`, por ejemplo `0.3.0+3`:

| Parte | Ejemplo | Regla | Dónde se ve |
|---|---|---|---|
| `versionName` | `0.3.0` | Versionamiento semántico MAJOR.MINOR.PATCH; es igual a la etiqueta de Git sin la `v` | En Google Play y en los ajustes del teléfono |
| `versionCode` | `3` | Número entero que **siempre sube** con cada build que se publica; Google Play rechaza un AAB con un número igual o menor al ya subido | Solo lo usa Android y Google Play |

Cuándo sube cada parte:

- **MAJOR** (1.0.0): la primera versión completa para clientes, al cerrar el Sprint 4.
- **MINOR** (0.3.0): cada cierre de sprint con historias de usuario nuevas.
- **PATCH** (0.3.1): una corrección publicada entre sprints, sin funciones nuevas.
- **versionCode**: +1 en cada versión publicada, sea MAJOR, MINOR o PATCH.

| Versión | `pubspec.yaml` | Canal |
|---|---|---|
| v0.1.0 | `1.0.0+1` (quedó con el valor que crea Flutter; se corrigió en v0.2.0) | GitHub Releases |
| v0.2.0 | `0.2.0+2` | GitHub Releases |
| v0.3.0 | `0.3.0+3` | GitHub Releases |
| v1.0.0 | `1.0.0+4` | GitHub Releases y Pruebas internas de Google Play |

## Flujo de una versión

```
develop  ──PR (checks + aprobación)──▶  main  ──etiqueta vX.Y.Z──▶  Release en GitHub
                                                                          │
                                       Publicar APK: regresión ──(pasa)──▶ APK adjunto
                                                                          │
                              (Sprint 4) AAB firmado ──▶ Google Play: Pruebas internas
```

1. Se sube `version:` en `pubspec.yaml` (versionName y versionCode) en el PR de cierre del sprint.
2. PR de `develop` a `main`: corren todos los pipelines y lo aprueba el otro integrante.
3. Se crea la etiqueta `vX.Y.Z` y el release en GitHub: corren regresión, rendimiento y esfuerzo.
4. Publicar APK compila solo si la regresión pasó; si falla, no hay APK y se abre una issue.
5. Desde el Sprint 4, el mismo código se compila como AAB firmado y se sube a Pruebas internas.
