# Datos de prueba

**Tarea:** #208 · Observación: "Integrar datos de prueba".

Las pruebas usan dos clases de datos: **simulados** (pruebas unitarias, de widgets y de flujo en `test/`) y **reales de prueba** (pruebas en el emulador contra el backend de Render, en `integration_test/`). Los datos reales de prueba están en un solo archivo, `integration_test/datos_prueba.dart`; las pruebas del emulador lo importan en lugar de repetir los valores.

## Datos simulados (`test/`)

No usan red ni cuentas. Cada archivo define su backend en memoria (por ejemplo `_Backend`, `_PersonalizacionFalsa`) y los registros de ejemplo que necesita su caso: pedidos, piezas, solicitudes. Así cada prueba controla exactamente qué responde el "servidor" y puede simular errores (sin sesión, sin conexión, rechazo del backend). Cada archivo explica en su encabezado (`// DATOS:`) qué datos usa.

## Datos reales de prueba (`integration_test/datos_prueba.dart`)

| Dato | Valor | De dónde sale | Quién lo usa |
|---|---|---|---|
| `CuentaPrueba.correo` y `.contrasena` | Cuenta de cliente de prueba | `env.json` en la computadora (no se sube a Git) o los secretos del repositorio en los pipelines | Todas las pruebas con sesión |
| Cuenta por pipeline | `PRUEBAS_*` (integración y regresión), `ACEPTACION_*` (aceptación), `ENTORNO_*` (entorno) | Secretos del repositorio | Cada pipeline del emulador usa la suya porque corren al mismo tiempo (#185) |
| `PiezasPrueba.personalizable` | 1 · Esclava personalizada Día del Padre | Catálogo real (admite personalización) | Aceptación HU-13, integración del Sprint 3 |
| `PiezasPrueba.pedidoSeguridad` | 1 | Catálogo real | Seguridad del pago |
| `PiezasPrueba.categoriaCompra` | Anillos | Catálogo real; se toma la pieza más barata con existencia | Catálogo, recorrido, aceptación HU-12, integración |
| `RegistrosAjenos.pedido`, `.apartado`, `.abono` | 16, 4 y 4 | Registros de **otra** cuenta | Seguridad del pago: el backend debe negar el acceso |
| `OpcionesPrueba.crearPedido` | `false` por defecto | `--dart-define=CREAR_PEDIDO=true` | Aceptación HU-11 (CA-10 a CA-13 crean pedidos reales) |
| `OpcionesPrueba.pagoMercadoPago` | `false` por defecto | `--dart-define=PAGO_MP=true` | Aceptación HU-12 (alguien paga en Mercado Pago) |
| `OpcionesPrueba.pausaWeb` | 0 por defecto | `--dart-define=PAUSA_WEB=40` | Pausa para capturar el sitio web junto a la app |
| `TiemposPrueba.espera` | 90 s | Fijo | Lo máximo que se espera algo en pantalla (Render puede estar despertando) |
| `TiemposPrueba.pasoManual` | 15 min | Fijo | Lo máximo que se espera a la tienda o a Mercado Pago |
| Comprador de Mercado Pago | Cuenta `TESTUSER…` | `env.json` de quien prueba (`MP_COMPRADOR_*`) | Pago en la aceptación HU-12 y la integración del Sprint 3 |

Cualquier valor numérico se puede cambiar sin tocar el código, por ejemplo `--dart-define=PIEZA_PERSONALIZABLE=81` si la pieza 1 dejara de existir.

## Datos que crean las pruebas y cómo se limpian

| Prueba | Qué crea | Limpieza |
|---|---|---|
| Aceptación HU-11 (con `CREAR_PEDIDO`) | Un pedido y un apartado | La tienda los cancela desde el panel |
| Aceptación HU-12 | Un pedido y un apartado pagados con el comprador de prueba | Se cancelan; el stock regresa como al cancelar un pedido pagado |
| Aceptación HU-13 | Una solicitud de personalización | Se cierra como rechazada con el motivo "Solicitud de prueba…" |
| Integración Sprint 3 | Un pedido pagado y una solicitud | Pedido cancelado con su pieza de vuelta en el stock; solicitud rechazada |
| Seguridad del pago | Un pedido sin pagar | Se cancela; no deja transacciones de pago |
| Aceptación HU-08 a HU-10, recorrido, entorno | Piezas en el carrito y favoritos | La propia prueba las quita al terminar |

Los registros de prueba usados hasta ahora quedan anotados en las tablas de resultados de cada prueba (`pruebas/aceptacion_hu*.md`, `integracion_sprint3.md`, `seguridad_pago_sprint3.md`).

## Protección de los datos

- `env.json` está en `.gitignore`; `env.example.json` solo trae los nombres de las variables.
- La prueba de seguridad `test/seguridad_test.dart` comprueba que la cuenta se lee al compilar desde `datos_prueba.dart` y que ningún archivo de `integration_test/` tiene un correo escrito.
- gitleaks revisa en cada PR que no haya claves en el código ni en el historial.
