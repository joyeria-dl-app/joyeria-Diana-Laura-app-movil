# Pruebas de caja negra Debug / Release · Sprint 4

**Tarea:** #277 · **Fecha:** 6 de noviembre de 2026 · **Tipo:** pruebas funcionales E2E manuales, sin ver el código

**Criterio de aceptación:** matriz completa con su evidencia; cada historia se ejecuta en Debug y en Release.

## Cómo se probó

Cada caso se hizo como lo haría una clienta: tocando la pantalla y revisando lo que se ve. No se usaron pruebas automatizadas ni se consultó el código. Los dos builds usan la misma cuenta de pruebas y el backend de producción (Render), y se ejecutaron uno junto al otro en el mismo momento.

| | Debug | Release |
|---|---|---|
| Dispositivo | Emulador Pixel 8, Android 16 (API 36), 411 dp | Motorola Moto G6 Plus, Android 9, 360 dp |
| APK | `flutter build apk --debug` | `--release --obfuscate --split-debug-info`, R8 con `isMinifyEnabled` e `isShrinkResources` (#275) |
| Código | `develop` con #274 y #276 | `develop` con #274, #275 y #276 |

Las capturas están en `Evidencias_App_Movil/Sprint4/214_caja_negra/` con el nombre `C<caso>_<nombre>_<debug|release>.png`.

## Matriz

| Caso | Historia | Pasos | Resultado esperado | Debug | Release |
|---|---|---|---|---|---|
| C01 | HU-03/04 Sesión | Abrir la app con sesión iniciada | Inicio con el saludo y el nombre de la clienta | Pasa | Pasa |
| C02 | HU-07 Catálogo | Tocar Catálogo | Categorías y filas por sección con sus piezas e imágenes | Pasa | Pasa |
| C03 | HU-07 Catálogo por categoría | Tocar Cadenas | Solo cadenas, paginadas ("21 piezas · página 1 de 4") | Pasa | Pasa |
| C04 | HU-08 Detalle | Tocar una pieza | Foto, nombre, existencias ("Quedan 4"), material, peso y precio | Pasa | Pasa |
| C05 | HU-09 Favoritos | Tocar el corazón en el detalle y abrir Favoritos | "Guardada en tus favoritos"; la pieza aparece en Favoritos | Pasa | Pasa |
| C06 | HU-10 Carrito | Tocar Agregar y abrir el carrito; sumar una pieza | "Agregada a tu carrito"; subtotal y total correctos | Pasa | Pasa |
| C07 | HU-14 Perfil | Tocar Perfil | Datos de la cuenta, contadores, interruptores de tema y avisos (#274) | Pasa | Pasa |
| C08 | HU-14 Historial | Mi perfil → Mis pedidos | Pestañas En curso, Entregados y Cancelados con sus pedidos | Pasa | Pasa |
| C09 | HU-13 Apartados | Mi perfil → Mis apartados | Apartados con su estado, lo abonado y lo que falta | Pasa | Pasa |
| C10 | HU-16 Zonas | Mi perfil → Zonas de entrega | Zonas con la tienda marcada y envío por terceros | Pasa | Pasa |
| C11 | HU-11 Seguimiento | Abrir un pedido en curso | Estado y línea de tiempo del pedido | Pasa | Pasa |
| C12 | HU-07 Búsqueda | Buscar "anillo" | Solo anillos ("17 piezas") | Pasa | Pasa |
| C13 | HU-15 Avisos push | El backend envía un aviso a la cuenta | Llega la notificación de la app a los dos teléfonos | Pasa | Pasa |

**13 de 13 casos pasan en Debug y en Release.** El pago con Mercado Pago (HU-12) y la personalización (HU-13) no se ejecutaron aquí para no crear cobros ni solicitudes reales; están cubiertos en `aceptacion_hu12.md` y `aceptacion_hu13.md`.

Al terminar se quitaron el favorito y las piezas del carrito que se agregaron, y la cuenta quedó como estaba.

### Observaciones

- **C06:** el carrito se guarda en el servidor y se comparte entre los dos teléfonos. Cada uno muestra la cantidad que tenía al abrir la pantalla; al volver a entrar se actualiza. Vaciarlo desde el Moto avisó "Se quitarán las 2 piezas", así que los dos builds escriben en el mismo carrito.
- **Release en Android 9:** logcat muestra `ClassNotFoundException: android.app.UiModeManager$ContrastChangeListener`. Esa clase existe desde Android 14 y Flutter la busca y sigue de largo cuando no está. Es un mensaje informativo, no un error: la app no se cierra y ningún caso falla. No tiene que ver con R8, porque se trata de una clase del sistema.

## Errores encontrados en Release y corregidos

Los errores de esta tabla solo aparecieron al usar el build de Release en un teléfono real. En el emulador con Debug no se veían.

| Error | Dónde apareció | Causa | Corrección | Verificación |
|---|---|---|---|---|
| #267 Botones de Inicio partidos en dos líneas | Moto G6 Plus (360 dp), APK de Release, en la prueba de #57 | El emulador mide 411 dp y ahí sí cabían; a 360 dp el relleno de Material 3 con la fuente Poppins no deja espacio | PR #268: menos relleno; si aun así no cabe, el texto se achica en lugar de partirse. Prueba de widget a 360 dp | C01 Release (sin sesión, evidencia 211): los dos botones en una línea |
| #269 Catálogo que parecía cargar todo de golpe | Moto G6 Plus, Release | Páginas de 20 piezas con categorías de 21 o menos | PR #270: páginas más cortas, y las filas por sección piden solo sus piezas | C03: "21 piezas · página 1 de 4" en los dos builds |
| #65 Sin forma de saber si la app falla en producción | Release (en Debug los errores se ven en la consola) | No había reporte de errores en el build de producción | PR #264: Firebase Crashlytics, activo solo en Release; envía los errores no controlados de Flutter y de la plataforma | Con R8 y `--obfuscate` (#275) se conservan archivo y línea, y los nombres se recuperan con `mapping.txt` y `build/simbolos` |
| R8 / ofuscación (#275) | Release | Riesgo de que R8 quite clases que Firebase usa por nombre | Reglas mínimas en `proguard-rules.pro`; Flutter y Firebase traen las suyas | C01–C13 en Release pasan: inicio de sesión con Firebase, avisos push y pinning funcionan |
