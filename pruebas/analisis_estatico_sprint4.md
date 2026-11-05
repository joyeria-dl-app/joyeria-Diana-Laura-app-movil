# Análisis de código estático · Sprint 4 (HU-14 a HU-17)

**Tarea:** #150 · **Fecha:** 4 de noviembre de 2026 · **Pipeline:** `.github/workflows/analisis-estatico.yml`

**Criterio de aceptación:** `flutter analyze` sin problemas en todos los PR del sprint.

## Resultado sobre `develop` (1d65cd6, HU-14 a HU-17 integradas)

| Revisión | Herramienta | Resultado |
|---|---|---|
| Reglas de flutter_lints | `flutter analyze --fatal-infos` | Sin problemas |
| Formato | `dart format --line-length 160` | 125 archivos, 0 por cambiar |
| Claves en el código y el historial | gitleaks (pipeline) | Sin hallazgos |
| Patrones inseguros | Semgrep (pipeline, desde #239) | Sin hallazgos |
| Dependencias vulnerables | Dependabot | 0 alertas abiertas |
| Dependencias desactualizadas | `flutter pub outdated` | 19 con versión nueva compatible (3 directas) |

La corrida del pipeline en `develop` sobre 1d65cd6 terminó bien: [run 41968588928](https://github.com/joyeria-dl-app/joyeria-Diana-Laura-app-movil/actions/runs/41968588928).

## Análisis estático en los PR del sprint

Los 22 PR unidos a `develop` en el Sprint 4 (del #215 al #264) pasaron el check "Análisis estático". Ninguno se unió con avisos de flutter_lints, código sin formato, claves expuestas ni hallazgos de Semgrep.

| PR | Resultado | PR | Resultado | PR | Resultado |
|---|---|---|---|---|---|
| #215 | Pasa | #227 | Pasa | #248 | Pasa |
| #218 | Pasa | #228 | Pasa | #253 | Pasa |
| #219 | Pasa | #229 | Pasa | #260 | Pasa |
| #223 | Pasa | #239 | Pasa | #261 | Pasa |
| #224 | Pasa | #243 | Pasa | #262 | Pasa |
| #225 | Pasa | #245 | Pasa | #263 | Pasa |
| #226 | Pasa | #246 | Pasa | #264 | Pasa |
| | | #247 | Pasa | | |

## Cambio

Se actualizaron las 19 dependencias dentro de las versiones que permite `pubspec.yaml` (`flutter pub upgrade`, solo cambia `pubspec.lock`):

| Paquete | Antes | Después |
|---|---|---|
| cached_network_image (directa) | 4.0.5 | 4.0.6 |
| firebase_messaging (directa) | 17.0.0 | 17.0.1 |
| flutter_local_notifications (directa) | 22.3.2 | 22.3.3 |
| cached_network_image_web | 2.0.3 | 2.0.4 |
| crypto | 3.0.7 | 3.0.8 |
| cupertino_ui | 1.1.4 | 1.1.6 |
| file_selector_macos | 0.9.5+1 | 0.9.5+2 |
| firebase_messaging_platform_interface | 4.11.0 | 4.11.1 |
| firebase_messaging_web | 4.3.0 | 4.3.1 |
| flutter_cache_manager | 3.4.6 | 3.5.0 |
| image_picker_ios | 0.8.13+10 | 0.8.13+14 |
| jni | 1.1.0 | 1.1.2 |
| material_ui | 1.8.0 | 1.10.0 |
| octo_image | 2.1.2 | 2.1.3 |
| sqflite_common | 2.5.14 | 2.5.15 |
| sqflite_darwin | 2.4.4+1 | 2.4.5 |
| vector_math | 2.4.3 | 2.4.4 |
| vm_service | 15.3.0 | 15.4.0 |
| web | 1.1.1 | 1.1.2 |

Las 3 directas son las mismas que proponían los PR de Dependabot #255, #257 y #258; con este cambio quedan cubiertas. El PR #232 (`actions/setup-node` 6 → 7) es de los pipelines y se revisa aparte.

Después del cambio: `flutter analyze` sin problemas, 362 pruebas pasan y el APK de producción compila (54.3 MB). Quedan `cross_file`, `material_color_utilities`, `objective_c` y `test_api` con versión nueva que el SDK de Flutter todavía no permite; se actualizan cuando cambie el SDK.
