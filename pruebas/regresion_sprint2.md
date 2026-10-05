# Pruebas de regresión · Sprint 2 (antes de la versión v0.2.0, tarea #143)

- **Alcance:** todo lo integrado hasta el Sprint 2 (HU-03 a HU-10).
- **Entorno:** emulador de Android (Android Studio, perfil Pixel 8), app en modo debug, backend real de Render.
- **Código probado:** rama `develop` después de los PRs #166 y #167 (actualizaciones de Dependabot).
- **Pipeline:** `.github/workflows/pruebas-regresion.yml` (al fusionar a `main`, al crear una versión y cada lunes).
- **Criterio de aceptación:** ninguna prueba que pasaba antes falla después de los cambios del sprint.
- **Fecha:** 5 de octubre de 2026.

## 1. Pruebas automáticas

| # | Revisión | Comando | Resultado |
|---|---|---|---|
| R-01 | Pruebas del Sprint 1 (versión v0.1.0, 7 archivos) corridas contra el código actual | `flutter test` sobre las pruebas de v0.1.0 | **29 de 29 pasan** |
| R-02 | Suite actual: unitarias, widgets y seguridad | `flutter test` | **134 pasan** |
| R-03 | Integración: catálogo, recorrido del cliente, aceptación y rendimiento | `flutter test integration_test --dart-define-from-file=env.json` | **4 de 4 pasan** (evidencia 156) |

En R-03 los 9 casos de aceptación (CA-01 a CA-09) pasaron otra vez, y las mediciones de rendimiento quedaron dentro de los límites: arranque 2,188 ms, catálogo 1,079 ms, detalle 2,186 ms, 7.4 % de cuadros perdidos al construir.

## 2. Casos manuales del Sprint 1 (inicio de sesión y registro)

| Caso | Qué se hizo | Resultado esperado | Resultado obtenido | Resultado | Evidencia |
|---|---|---|---|---|---|
| M-01 | Iniciar sesión con el correo `ana@` | Aviso de correo inválido | "Ingresa un correo válido" | Pasa | 157 |
| M-02 | Correo de prueba con contraseña equivocada | Mensaje de error, no entra | "Correo o contraseña incorrectos. Te quedan 2 intentos." | Pasa | 158 |
| M-03 | Correo y contraseña correctos | Entra y saluda al cliente | "Hola, Valentina Bautista Hernández" | Pasa | 159 |
| M-04 | Cerrar sesión | Vuelve al inicio sin cuenta | Inicio con Iniciar sesión / Crear cuenta / Explorar sin cuenta | Pasa | 160 |
| M-05 | Escribir la contraseña poco a poco en el registro | Las reglas se marcan mientras se escribe | Se marcan Mayúscula, Número y 8 caracteres conforme se cumplen | Pasa | 161–163 |
| M-06 | Registro con datos válidos y Continuar | Pasa a la pregunta secreta | Paso 2 de 2 "Protege tu cuenta" (no se terminó el registro) | Pasa | 164–165 |
| M-07 | Explorar sin cuenta | Abre el catálogo | "Nuestras joyas" con las piezas | Pasa | 166 |

## Resultado

Ninguna prueba que pasaba antes falla: las 29 pruebas del Sprint 1 pasan sin cambios, la suite actual pasa completa y los 7 casos manuales del Sprint 1 se comportan igual. Se cumple el criterio de aceptación y `develop` queda listo para la versión v0.2.0.

## Cambios al pipeline de regresión

- Corre las pruebas de la versión anterior (último tag) contra el código actual.
- Corre las tres pruebas de integración con sesión (catálogo, recorrido del cliente y aceptación) con la cuenta de prueba de los secretos; antes solo corría la del catálogo. Rendimiento se mantiene en su propio pipeline.
