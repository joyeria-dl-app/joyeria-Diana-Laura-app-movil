# Despliegue de la app móvil vía Google Play

**Tarea:** #210 · Observación: "Se recomienda revisar la forma de despliegue vía Google Play, especificando la versión".

## Cómo se despliega hoy (Sprints 1 a 3)

Al cerrar cada sprint, `develop` se une a `main`, se crea la etiqueta de versión y se publica en **GitHub Releases**. El workflow **Publicar APK** corre la regresión completa y, solo si pasa, compila el APK de producción y lo adjunta a la versión. Quien prueba la app la descarga de ahí y la instala en su teléfono.

| Versión | Sprint | Fecha | Canal | Archivo |
|---|---|---|---|---|
| v0.1.0 | Sprint 1 | 27 sep 2026 | GitHub Releases | APK |
| v0.2.0 | Sprint 2 | 5 oct 2026 | GitHub Releases | `joyeria-diana-laura-v0.2.0.apk` |
| v0.3.0 | Sprint 3 | 26 oct 2026 (#92) | GitHub Releases | `joyeria-diana-laura-v0.3.0+3.apk` |

## Cómo se desplegará con Google Play (Sprint 4, HU-17)

Google Play no acepta APK firmados con la llave de depuración: pide un **Android App Bundle (AAB)** firmado con una llave de subida propia. El paso a Google Play queda en la HU-17 (#61):

| Paso | Tarea | Qué se hace |
|---|---|---|
| 1. Firma | #62 (hecho) | Llave de subida `upload-keystore.jks` (RSA 2048, alias `upload`), guardada fuera del repositorio por el equipo. `android/app/build.gradle.kts` firma el build de producción con ella leyendo `android/key.properties` (ignorado por Git); sin ese archivo, como en los pipelines, firma con la llave de depuración. Google guarda la llave final (Play App Signing). |
| 2. Build | #63 (hecho) | `flutter build appbundle --release` genera el AAB firmado. Ver [Generar el AAB](#generar-el-aab). |
| 3. Pruebas internas | #64 (AAB listo; falta la cuenta) | Subir el AAB al canal **Pruebas internas** de Google Play Console; los testers (el equipo y la maestra) instalan la app desde Google Play con un enlace de invitación. |
| 4. Errores | #65 (hecho) | Firebase Crashlytics reporta los errores no controlados de Flutter y de la plataforma; solo en el build de producción (`kReleaseMode`). Los reportes se ven en Firebase Console > Crashlytics. |
| 5. Versión final | #93 | v1.0.0: develop se une a main, se publica en GitHub Releases y el mismo AAB se sube a Google Play. |

### Canales de Google Play

| Canal | Para qué | Quién la instala | Uso en el proyecto |
|---|---|---|---|
| Pruebas internas | Probar la versión en teléfonos reales en minutos, sin revisión larga de Google | Hasta 100 testers invitados por correo | v1.0.0 (Sprint 4) |
| Pruebas cerradas | Probar con un grupo mayor; Google la revisa | Lista de testers o grupos | Si la tienda quiere probar con clientes |
| Producción | Publicar para todos | Cualquier usuario de Google Play | Fuera del alcance del cuatrimestre; requiere la cuenta de desarrollador de la tienda |

Una versión solo avanza de canal (internas → cerradas → producción) si pasó en el canal anterior.

## Generar el AAB

Requisitos en la computadora que compila: `android/key.properties` con la ruta del keystore y sus contraseñas, y `env.json` con las variables de la app.

```properties
storePassword=<contraseña>
keyPassword=<contraseña>
keyAlias=upload
storeFile=<ruta>/upload-keystore.jks
```

```bash
flutter build appbundle --release --dart-define-from-file=env.json
# Revisar que lo firmó la llave de subida y no la de depuración
jarsigner -verify -verbose:summary -certs build/app/outputs/bundle/release/app-release.aab
```

Resultado del 4 nov 2026 (versión `0.3.0+3`): `build/app/outputs/bundle/release/app-release.aab`, 53.1 MB, firmado por `CN=Joyeria Diana Laura, OU=App Movil, O=Joyeria Diana Laura, L=Huejutla, ST=Hidalgo, C=MX`. Para la v1.0.0 (#93) se vuelve a generar con `1.0.0+4` en `pubspec.yaml`.

## Estado de Pruebas internas (#64)

Al 4 nov 2026 el equipo **no tiene la cuenta de desarrollador de Google Play Console** (pago único de 25 USD). Por eso el AAB no se ha subido, pero todo lo que depende del proyecto está listo:

| Requisito | Estado |
|---|---|
| Llave de subida (#62) | Lista, guardada fuera del repositorio |
| AAB firmado con la llave de subida (#63) | Listo y verificado con `jarsigner` |
| Versión (`versionName`/`versionCode`) | Se valida en el pipeline; la v1.0.0 sale con `1.0.0+4` |
| `applicationId` | `com.joyeriadianalaura.joyeria_diana_laura` (no cambia después de subir la primera versión) |
| Cuenta de Google Play Console | **Pendiente** (decisión del equipo) |

Mientras tanto, la app se distribuye por **GitHub Releases** como APK, igual que en los sprints anteriores.

### Pasos cuando exista la cuenta

1. Crear la cuenta en [Play Console](https://play.google.com/console), pagar los 25 USD y verificar la identidad.
2. **Crear app**: nombre "Joyería Diana Laura", idioma español (México), tipo App, gratuita.
3. En **Prueba > Pruebas internas**, crear una lista de testers con los correos del equipo y de la maestra.
4. **Crear versión**: aceptar **Play App Signing** (Google guarda la llave final y nuestra llave queda como llave de subida) y subir `app-release.aab` de la v1.0.0.
5. Escribir las notas de la versión, revisar y **Lanzar en Pruebas internas**.
6. Copiar el **enlace de invitación** y mandarlo a los testers; cada uno acepta y instala la app desde Google Play.
7. Llenar lo que Play Console pide antes de pasar a otros canales: política de privacidad, clasificación de contenido, seguridad de los datos y ficha de la tienda.

Si la llave de subida se pierde después de activar Play App Signing, se pide a Google un cambio de llave de subida desde Play Console; la app no se pierde.

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

### Dónde se valida la versión en el pipeline

El workflow `.github/workflows/release-apk.yml` (Publicar APK) tiene el paso **Revisar la versión**: lee `version:` de `pubspec.yaml`, la compara con la etiqueta del release y, si no coinciden (por ejemplo, etiqueta `v0.3.0` con `pubspec.yaml` en `0.2.0+2`), detiene la publicación con un error. Si coinciden, compila con `--build-name` y `--build-number` y escribe la versión en el resumen de la corrida.

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
4. Publicar APK revisa que la etiqueta coincida con `version:` de `pubspec.yaml` (si no, se detiene), compila con ese versionName y versionCode solo si la regresión pasó, y nombra el archivo con la versión completa (`joyeria-diana-laura-v0.3.0+3.apk`). Si algo falla, no hay APK y se abre una issue.
5. Desde el Sprint 4, el mismo código se compila como AAB firmado y se sube a Pruebas internas.
