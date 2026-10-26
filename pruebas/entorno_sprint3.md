# Pruebas de entorno · Sprint 3

- **Prueba automatizada:** `integration_test/entorno_test.dart`, que se corre con `pruebas/entorno.sh`.
- **Pipeline:** `.github/workflows/pruebas-entorno.yml`. Corre en cada integración a `develop` y al pedir unir `develop` a `main`, y guarda las capturas de cada caso como artefacto.
- **Entorno:** emulador de Android 14 (Android Studio, perfil Pixel 8), app en modo debug, backend real de Render.
- **Cuenta:** cliente de prueba (secretos `PRUEBAS_CORREO` y `PRUEBAS_CONTRASENA`). Al terminar, la prueba vacía el carrito y cierra la sesión.
- **Cómo se simula cada situación:** la app no puede cambiar la batería, recibir llamadas ni quitarse la señal. Por eso la prueba avisa cuándo está lista ("ENTORNO PASO <caso>") y el script lo aplica en el emulador con `adb`. Al final, pase o falle, el script deja el emulador como estaba: batería al 100 % y sin modo avión.
- **Situación de partida:** una compra a medias, con una pieza en el carrito y la pantalla del carrito abierta.
- **Fecha de ejecución:** 6 de octubre de 2026.

## Casos

| Caso | Situación | Cómo se simula | Qué se comprueba | Resultado obtenido | Resultado | Evidencia |
|---|---|---|---|---|---|---|
| CE-01 | Batería baja | `adb emu power capacity 5`, sin cargador | La app sigue respondiendo | Con 5 % de batería el carrito sigue en pantalla y el catálogo carga | Pasa | 78, 79 |
| CE-02 | Llamada entrante | `adb emu gsm call`, se contesta y se cuelga | No se pierde la compra | La llamada aparece como aviso encima de la app; durante la llamada y al colgar sigue el carrito con la pieza y la sesión | Pasa | 80, 81, 82 |
| CE-03 | Segundo plano | Botón Inicio con `adb` y se vuelve a abrir la app 6 s después | Al volver sigue donde estaba | La app pasó a segundo plano y regresó al carrito con la pieza y la sesión abierta | Pasa | 83, 84 |
| CE-04 | Sin señal | Modo avión con `adb` | La app avisa y no se cierra | Mis pedidos muestra "Sin conexión" con el botón Reintentar | Pasa | 85 |
| CE-05 | Regresa la señal | Se quita el modo avión | La app vuelve a cargar | Al tocar Reintentar, Mis pedidos carga los pedidos | Pasa | 86 |

**Resultado:** pasan los 5 casos. La app no se cierra ni pierde la compra en curso ante batería baja, una llamada, el paso a segundo plano o la falta de señal.

Inicio de la tarea: evidencia 77.

## Observaciones

- En Android 14, una llamada entrante con la app abierta aparece como un aviso en la parte de arriba y no saca a la app del primer plano, ni siquiera al contestar. Por eso el paso a segundo plano se prueba aparte (CE-03), como cuando el cliente sale a la pantalla de inicio para atender el teléfono.
- Las dos primeras corridas fallaron por errores de la prueba, no de la app. En la primera, la prueba buscaba en el catálogo una pieza que no aparece en la primera pantalla. En la segunda, esperaba que la llamada mandara la app a segundo plano. Se corrigieron y la tercera corrida pasó completa.

## Cómo ejecutarla

```
bash pruebas/entorno.sh
```

Se necesita el emulador abierto (`DISPOSITIVO`, por defecto `emulator-5554`) y `env.json`. Con `CAPTURAS=carpeta` guarda una captura de pantalla de cada caso.

## Corrección #202: prueba estable al volver del segundo plano (11 de octubre de 2026)

En `develop`, tras el PR #201, la corrida 38172994278 falló en CE-04 en su primer intento y pasó al reintentarla. Al volver a abrir la app desde segundo plano, la salida de `flutter test` dejó de traer los avisos `ENTORNO` de la app; `entorno.sh` nunca vio "PASO sin_senal", no activó el modo avión y la prueba no encontró "Sin conexión".

Cambios:
- La prueba escribe cada aviso también en `entorno_pasos.txt`, dentro de la carpeta temporal de la app, y `entorno.sh` lo lee cada segundo con `adb shell run-as`. Cada paso se aplica una sola vez aunque llegue por los dos caminos. Se intentó primero con `adb logcat`, pero dentro de `flutter test` los mensajes de la app no llegan a logcat.
- Antes de CE-04 la prueba espera a que el teléfono se quede sin red (abre una conexión real). Si el modo avión no se activa en 60 s, falla con esa causa.
- Los workflows usan `ubuntu-24.04` en lugar de `ubuntu-latest`, que cambia a Ubuntu 26 el 19 de octubre.

| Comprobación | Resultado |
|---|---|
| Local, script normal, 2 corridas seguidas | 5/5 cada una, 7 acciones de adb, ningún paso repetido |
| Local, solo con el archivo (sin la salida de flutter test) | 5/5 |
| Pipeline, 3 corridas seguidas (#20, #21, #22), primer intento | 5/5 cada una |

Las corridas #18 y #19 del pipeline fallaron antes de CE-01 porque se lanzaron al mismo tiempo que la #17 con la misma cuenta y compartían el carrito del servidor; no tienen relación con el cambio.
