# Análisis de código estático · Sprint 3 (HU-11 a HU-13)

**Tarea:** #145 · **Fecha:** 11 de octubre de 2026 · **Pipeline:** `.github/workflows/analisis-estatico.yml`

**Criterio de aceptación:** `flutter analyze` sin problemas en todos los PR del sprint.

## Resultado sobre `develop` (763be8f, HU-11 a HU-13 integradas)

| Revisión | Herramienta | Resultado |
|---|---|---|
| Reglas de flutter_lints | `flutter analyze --fatal-infos` | Sin problemas |
| Formato | `dart format --line-length 160` | 87 archivos, 0 por cambiar |
| Claves en el código y el historial | gitleaks | Sin hallazgos |
| Dependencias vulnerables | Dependabot | 0 alertas abiertas |
| Dependencias desactualizadas | `flutter pub outdated` | 10 con versión nueva compatible (1 directa: url_launcher 6.3.2 → 6.3.3) |

## Análisis estático en los PR del sprint

Los 21 PR unidos a `develop` en el Sprint 3 (del #175 al #200) pasaron el check "Análisis estático". Ninguno se unió con avisos de flutter_lints ni con código sin formato.

| PR | Resultado | PR | Resultado | PR | Resultado |
|---|---|---|---|---|---|
| #175 | Pasa | #184 | Pasa | #194 | Pasa |
| #176 | Pasa | #186 | Pasa | #195 | Pasa |
| #178 | Pasa | #187 | Pasa | #196 | Pasa |
| #179 | Pasa | #188 | Pasa | #197 | Pasa |
| #180 | Pasa | #190 | Pasa | #198 | Pasa |
| #181 | Pasa | #191 | Pasa | #199 | Pasa |
| #183 | Pasa | #192 | Pasa | #200 | Pasa |

## Cambio

Se actualizaron las 10 dependencias dentro de las versiones que permite `pubspec.yaml` (`flutter pub upgrade`, solo cambia `pubspec.lock`):

| Paquete | Antes | Después |
|---|---|---|
| url_launcher (directa) | 6.3.2 | 6.3.3 |
| code_assets | 1.2.1 | 2.1.0 |
| hooks | 2.0.2 | 2.2.0 |
| image_picker_ios | 0.8.13+9 | 0.8.13+10 |
| jni | 1.0.3 | 1.1.0 |
| jni_flutter | 1.0.3 | 1.0.4+1 |
| meta | 1.18.3 | 1.19.0 |
| objective_c | 9.5.0 | 9.6.2 |
| record_use | 0.6.0 | 1.1.1 |
| vector_math | 2.4.0 | 2.4.3 |

Después del cambio: `flutter analyze` sin problemas, 255 pruebas pasan y el APK de producción compila. Quedan `cross_file`, `material_color_utilities` y `test_api` con versión nueva que el SDK de Flutter todavía no permite; se actualizan cuando cambie el SDK.
