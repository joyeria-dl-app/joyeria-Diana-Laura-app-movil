# Pruebas de regresión · Sprint 3 (antes de la versión v0.3.0, tarea #148)

- **Alcance:** todo lo integrado hasta el Sprint 3 (HU-01 a HU-13).
- **Entorno:** emulador de Android (Android Studio, perfil Pixel 8), app en modo debug, backend real de Render. En GitHub Actions, emulador Android 14 con perfil Pixel 6.
- **Código probado:** rama `develop` en el commit `15f37b1`, después de unir el PR #231 (#230).
- **Pipeline:** `.github/workflows/pruebas-regresion.yml` (al unir a `main`, al crear una versión, antes de compilar el APK y cada lunes sobre `develop`).
- **Criterio de aceptación:** ninguna prueba que pasaba antes falla después de los cambios del sprint.
- **Fecha:** 25 y 26 de octubre de 2026.

## 1. Pruebas automáticas

Corrida [40244185522](https://github.com/joyeria-dl-app/joyeria-Diana-Laura-app-movil/actions/runs/40244185522) de Pruebas de regresión sobre `develop`.

| # | Revisión | Resultado |
|---|---|---|
| R-01 | Suite actual: unitarias, widgets y seguridad | **255 pasan** |
| R-02 | Pruebas de la versión anterior (v0.2.0) corridas contra el código actual | **134 de 134 pasan** |
| R-03 | Pruebas de integración en el emulador contra el backend real, con la cuenta de prueba | **4 de 4 pasan** |

Los resultados de las tres partes se pueden descargar de la corrida (artefactos `regresion-unitarias` y `regresion-integracion`).

Con el mismo commit también pasaron en `develop` los demás pipelines: análisis estático, unitarias, integración, aceptación, entorno y rendimiento.

### Falla que detectó la regresión y cómo se resolvió

La corrida programada del 19 de octubre (run 39313599010) falló en R-02: una prueba de seguridad de v0.2.0 revisa que cualquier prueba del emulador que mencione `PRUEBAS_CORREO` la lea al compilar. Después de #208 la cuenta de prueba se lee en un solo archivo (`integration_test/datos_prueba.dart`) y las demás pruebas solo nombraban la variable en sus mensajes de error. La cuenta seguía fuera del código; se cambiaron esos mensajes para que no nombren la variable y la regla de v0.2.0 volviera a aplicar sin quitar la prueba (#230, PR #231).

## 2. Casos manuales de catálogo, detalle y carrito

| Caso | Qué se hizo | Resultado esperado | Resultado obtenido | Resultado | Evidencia |
|---|---|---|---|---|---|
| M-01 | Explorar sin cuenta | Abre el catálogo con categorías y piezas | "Nuestras joyas" con las categorías y las piezas | Pasa | 76 |
| M-02 | Elegir la categoría Anillos | Solo se muestran anillos | "Anillos", 17 piezas | Pasa | 77 |
| M-03 | Abrir una pieza con existencias | Detalle con nombre, precio, descripción y Agregar | "Anillo de promesa piedra rosa baño en rodio", $449.50 MXN, descripción y botón Agregar | Pasa | 78 |
| M-04 | Abrir el carrito sin cuenta | Pide iniciar sesión | "Inicia sesión para usar tu carrito" con el botón Iniciar sesión | Pasa | 79 |
| M-05 | Con la cuenta de prueba, agregar la pieza desde el detalle | Aviso de que se agregó | "Agregada a tu carrito" con Ver carrito | Pasa | 80 |
| M-06 | Abrir el carrito | La pieza con su precio y el total | 1 pieza, total $449.50 | Pasa | 81 |
| M-07 | Agregar una más | Cantidad 2 y total doble | 2 piezas, subtotal y total $899.00 | Pasa | 82 |
| M-08 | Quitar una y luego la otra | El carrito queda vacío | 0 piezas, "Tu carrito está vacío" | Pasa | 83 |

Antes de M-05 el carrito de la cuenta de prueba estaba vacío y al terminar M-08 quedó vacío otra vez, así que los pipelines que usan esa cuenta no se ven afectados.

**Observación (sin cambio respecto a v0.2.0):** la barra inferior del carrito muestra el total sin centavos cuando son cero ("$899") y el resumen lo muestra con centavos ("$899.00"). Es el formato de los bocetos (`formatoPrecio` y `formatoPrecioCompleto` en `lib/utils/formato.dart`) y no cambió en el Sprint 3.

## Resultado

Ninguna prueba que pasaba antes falla: la suite actual pasa completa, las 134 pruebas de v0.2.0 pasan contra el código del Sprint 3, las 4 pruebas de integración pasan en el emulador y los 8 casos manuales de catálogo, detalle y carrito se comportan igual que en la versión anterior. Se cumple el criterio de aceptación y `develop` queda lista para la versión v0.3.0 (#92).
