# Prueba de aceptación #276 · Diálogo que explica el permiso de notificaciones

**Tarea:** #276 · **Fecha:** 6 de noviembre de 2026 · **Tipo:** prueba manual en emulador

**Criterio de aceptación:** el permiso del sistema solo se pide si el usuario acepta el diálogo.

## Qué hace

- Al iniciar sesión (o al abrir la app con la sesión guardada), la app revisa si ya tiene el permiso de notificaciones. Si ya lo tiene, no muestra nada.
- Si no lo tiene, muestra "¿Te avisamos de tus pedidos?", que explica que la notificación llega cuando el pedido cambia de estado, que no se usa para publicidad y que se puede apagar en Mi perfil (#274).
- **Permitir:** se pide el permiso de Android. **Ahora no:** no se pide y no se vuelve a preguntar mientras la app siga abierta; se pregunta otra vez la siguiente vez que se abra.
- Nada de esto impide usar la app.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8, API 36 (en Android 13 o más el permiso se pide en tiempo de ejecución) |
| App | APK debug de la rama `feature/permiso-notificaciones` |
| Preparación | Permiso de notificaciones revocado con `adb shell pm revoke` y sin marcas de "no volver a preguntar" |
| Cuenta | Cuenta de pruebas |

## Resultados

| Caso | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|
| CA-51 | Sin permiso, al iniciar sesión aparece el diálogo de la app con Permitir y Ahora no, antes de cualquier aviso del sistema | Pasa | 208 |
| CA-52 | "Ahora no": no aparece el aviso de Android y el permiso sigue negado (`granted=false`); la app funciona igual | Pasa | 208a |
| CA-53 | Al volver a abrir, "Permitir": aparece el aviso de Android; al aceptarlo queda `granted=true` | Pasa | 208b |
| CA-54 | Con el permiso concedido, al abrir la app ya no aparece el diálogo | Pasa | 208c |

**4 de 4 casos pasan.**

## Pruebas automatizadas

- `test/notificaciones_service_test.dart`: "Ahora no" no pide el permiso del sistema ni registra el teléfono (y no vuelve a preguntar en la misma sesión), "Permitir" lo pide y registra, y con el permiso concedido no aparece el diálogo.
- `test/notificaciones_flujo_test.dart`: con la app completa, los mismos casos más "Permitir" con Android negando el permiso.
- `test/permiso_notificaciones_test.dart`: botones del diálogo, tamaño de 48 dp, etiquetas y contraste.

Con ellas pasan 403 pruebas; `flutter analyze` sin problemas.
