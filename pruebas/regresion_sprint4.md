# Regresión final del Sprint 4 · antes de la versión v1.0.0

**Tarea:** #153 · **Fecha:** 6 de noviembre de 2026 · **Rama probada:** `develop` con todo el Sprint 4 (hasta el PR #290) + las correcciones de esta tarea

**Criterio de aceptación:** ninguna prueba falla antes de publicar la versión 1.0.0.

## Resultado

| Prueba | Dónde | Resultado |
|---|---|---|
| Suite completa (`flutter test`): unitarias, widget, flujos y seguridad | Local y pipeline Pruebas de regresión | **403 de 403 pasan** |
| `flutter analyze` | Local | Sin problemas |
| Pruebas de la versión anterior (v0.3.0) contra el código actual | Pipeline Pruebas de regresión | 234 pasan; las 21 que no pasan cambiaron a propósito (ver abajo). **0 regresiones** |
| Integración en emulador: catálogo, recorrido de la clienta, aceptación HU-08/09/10, aceptación de pedidos | Pipeline Pruebas de regresión (Android 14, Pixel 6) | **4 de 4 pasan** |
| Integración (catálogo + recorrido) | Pipeline Pruebas de integración | Pasa |
| Aceptación (HU-08 a HU-10 + pedidos) | Pipeline Pruebas de aceptación | Pasa |
| Entorno (batería baja, llamada, sin señal) | Pipeline Pruebas de entorno | Pasa |
| Rendimiento (arranque, catálogo, detalle, scroll) | Pipeline Pruebas de rendimiento, último merge en `develop` | Pasa (catálogo en 1609 ms) |
| Casos de aceptación de los sprints anteriores | Matriz de caja negra #277 (13 casos en Debug y Release) | 13 de 13 pasan |

Las corridas de los pipelines en la rama `feature/regresion-final` quedan en Actions: regresión 42190366314; integración 42185979626; aceptación 42185983825; entorno 42185975268.

## Fallas encontradas en la regresión y su corrección

### 1. Las pruebas de integración no encontraban la pieza (desde el PR #280)

- **Síntoma:** desde el PR #280, los pipelines de integración, aceptación y entorno fallaban en `develop` con "No hay piezas con existencias en el filtro" o con una pieza `null`.
- **Causa:** el catálogo pasó a páginas numeradas de 6 piezas (#279). Las pruebas solo bajaban por la primera página o pedían solo la primera página al servidor. En Anillos, las 6 primeras piezas están agotadas.
- **Corrección:** `integration_test/paginas.dart` con dos ayudas:
  - `todasLasPiezas`: pide al servidor todas las páginas.
  - `buscarEnPaginas`: en la pantalla baja y, si la pieza no aparece, toca "Página siguiente".

  Se usan en `recorrido_cliente_test`, `aceptacion_test`, `aceptacion_pago_test`, `aceptacion_pedidos_test`, `integracion_compra_test` y `entorno_test`. La app no cambió: el error estaba en las pruebas.
- **Por qué no se vio antes:** esos pipelines corren al unir a `develop`, no en el PR. Las issues automáticas (#249–#252, #259) eran de una corrida anterior del 29 de octubre y nadie las revisó a tiempo.

### 2. La regresión contra la v0.3.0 bloqueaba la publicación

- **Síntoma:** 21 de las 255 pruebas de la v0.3.0 fallan contra el código actual. Como `release-apk.yml` corre esta regresión antes de compilar, la v1.0.0 no se habría podido publicar.
- **Causa:** son comportamientos que cambiaron a propósito en el Sprint 4:
  - catálogo por secciones (#254) y páginas numeradas de 6 (#279);
  - inicio rediseñado (#212);
  - la URL del servidor se movió a `app_config.dart`, y sigue siendo HTTPS.

  Cada una tiene una prueba nueva que cubre el comportamiento actual.
- **Corrección:**
  - `.github/regresion-reemplazadas.txt` lista esas 21 pruebas con su motivo y la prueba que la reemplaza.
  - `.github/scripts/revisar_regresion.py` lee el resultado y **falla si se rompe cualquier otra prueba vieja**. También avisa si una de la lista vuelve a pasar.

  No se apagó el paso: sigue detectando regresiones reales. Al publicar la v1.0.0, la versión anterior pasa a ser esa y la lista se vacía.

### 3. El emulador reinstalaba la app a mitad de una prueba

- **Síntoma:** en el pipeline de regresión, `catalogo_test` no terminaba (`did not complete`) y las demás fallaban con `adb uninstall failed`. Pasó igual en dos corridas seguidas.
- **Causa:** con varios archivos, `flutter test` empezaba a cargar el siguiente mientras otro seguía corriendo en el mismo emulador.
- **Corrección:** `--concurrency=1` en los pipelines de regresión, integración y aceptación. Con eso las pruebas corren una tras otra.

### Observación: rendimiento en el emulador local

En la computadora del equipo, con el emulador en modo debug, la prueba de rendimiento supera los límites: arranque de 3.3 s y catálogo de 3.2 s. El arranque no depende del servidor, así que es la velocidad de la máquina. En el pipeline la misma prueba pasa (catálogo en 1609 ms), y los tiempos del servidor medidos con curl son de 0.25 a 0.36 s por petición. **No se cambiaron los límites**; la referencia es el pipeline.

## Issues relacionadas

- #249, #250, #251, #252 y #259 (fallas automáticas de pipeline en `develop`): resueltas con las correcciones 1 y 3. Se cierran cuando estos cambios lleguen a `develop` y sus pipelines pasen.
- Historias padre con todas sus subtareas cerradas: #49 (HU-14), #53 (HU-15) y #94 (HU-19). #87 (HU-18) se cierra con la v1.0.0 (#93).
