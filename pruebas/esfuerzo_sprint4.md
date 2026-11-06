# Pruebas de esfuerzo · Sprint 4

**Tarea:** #155 · **Fecha:** 5 de noviembre de 2026 · **Script:** `pruebas/esfuerzo/catalogo.js` · **Pipeline:** `pruebas-esfuerzo.yml`

**Criterio de aceptación:** con 50 usuarios simultáneos el 95 % de las respuestas tarda menos de 2 s y menos del 1 % falla.

## Qué cambió respecto al Sprint 3

En el Sprint 3 (#149, `esfuerzo_sprint3.md`) cada usuario simulado pedía el catálogo, el detalle, el carrito, los pedidos y los apartados. En el Sprint 4 la app usa más rutas, así que el script recorre la app completa:

| Grupo | Rutas | Nuevo en el Sprint 4 |
|---|---|---|
| Inicio | `/content/carrusel-inicio` | Sí |
| Catálogo | `/products/categorias`, `/products/filter` con `limit=6` y una categoría al azar, `/products/:id` | Páginas de 6 por categoría (#279) |
| Carrito y pedidos | `/carrito`, `/carrito/pedidos/mis`, `/apartados/mis-apartados` | No |
| Perfil | `/favoritos`, `/auth/profile`, `/zonas-entrega` | Sí |
| Notificaciones | `POST` y `DELETE /notificaciones/dispositivo` | Sí |
| Inicio de sesión | `POST /auth/login/movil`, cada 5 vueltas | Sí |

Para las notificaciones cada usuario simulado registra un token falso propio (`prueba-esfuerzo-k6-usuario-<n>`) y lo borra en la misma vuelta, como hace la app al iniciar y cerrar sesión; no queda ningún token en la base. El inicio de sesión reutiliza el token de Firebase que se obtiene una vez en `setup()`, para cargar el backend y no Firebase. No se crean pedidos ni pagos.

Antes de la carga se pidió cada ruta nueva una vez contra Render y todas respondieron 200. El registro del teléfono rechazó el primer token falso porque el backend exige al menos 20 caracteres; por eso el token se alargó.

## Preparación: límite de peticiones por IP

Igual que en el Sprint 3, solo durante la prueba se subió `RASP_RATE_LIMIT_MAX` a 100000 en Render (evidencias 188 y 188a) y se comprobó en la cabecera `x-ratelimit-limit`. Al terminar se regresó a 500 (evidencia 190) y la cabecera volvió a decir 500.

## Resultados

| Entorno | Escenario | Usuarios | Peticiones | 95 % de respuestas | Errores | Recuperación (95 %) | Resultado | Evidencia |
|---|---|---|---|---|---|---|---|---|
| Aislado (GitHub) | Criterio | 50 | 22,844 (~95/s) | 2.7 ms | 0 % | 3.4 ms | Pasa | 189 |
| Aislado (GitHub) | Escalones | 25 → 150 | 123,401 (~280/s) | — | 0 % | 3.9 ms | Pasa | 189a |
| Render | Criterio | 50 | 13,825 (~56/s) | **0.69 s** | **0 %** | 0.34 s | **Pasa** | 189b |
| Render | Escalones | 25 → 150 | 36,164 (~81/s) | 2.05 s | 0 % | 0.38 s | Sin errores; tiempos al límite | 189c |

En Render las 49,983 comprobaciones de las dos corridas dieron el resultado esperado (todas las rutas respondieron 200, y 2xx en el registro del teléfono).

El entorno aislado solo prueba las rutas sin sesión (no tiene cuentas de clientes) y el backend y la base están en la misma máquina; por eso sus tiempos son de milisegundos. Sirve para revisar que el backend no falla bajo carga; la medición que cuenta para el criterio es la de Render.

## Comparación con el Sprint 3

| Render, 50 usuarios | Sprint 3 | Sprint 4 |
|---|---|---|
| Rutas por vuelta | 6 | 12 a 13 |
| 95 % de respuestas | 0.60 s | 0.69 s |
| Errores | 0 % | 0 % |
| Escalones hasta 150: 95 % | 1.94 s | 2.05 s |

Con el doble de rutas por usuario los tiempos subieron poco. El límite del servidor sigue en el mismo lugar: unas **80 a 95 peticiones por segundo** en el plan gratuito de Render. Por encima de unos **100 usuarios simultáneos** el 95 % de las respuestas pasa de 2 s, aunque el servidor no rechaza peticiones. Después de la carga el servidor se recupera en ambos casos.

## Cómo repetirla

```
# En GitHub: Actions → Pruebas de esfuerzo → Run workflow (entorno aislado o produccion; escenario criterio o quiebre)
k6 run -e ESCENARIO=criterio -e USUARIOS=50 pruebas/esfuerzo/catalogo.js
k6 run -e ESCENARIO=quiebre -e MAXIMO=150 pruebas/esfuerzo/catalogo.js
```

Antes de correrla contra Render hay que subir el límite por IP y regresarlo a 500 al terminar.
