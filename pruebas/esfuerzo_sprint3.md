# Pruebas de esfuerzo · Sprint 3

**Tarea:** #149 · **Fecha:** 11 de octubre de 2026 · **Script:** `pruebas/esfuerzo/catalogo.js` · **Pipeline:** `pruebas-esfuerzo.yml`

**Criterio de aceptación:** con 50 usuarios simultáneos el 95 % de las respuestas tarda menos de 2 s y menos del 1 % falla.

## Qué hace cada usuario simulado

Lo mismo que un cliente en la app, cada segundo:

1. Categorías (`/products/categorias`)
2. Una página del catálogo (`/products/filter`)
3. El detalle de una pieza al azar (`/products/:id`)
4. Su carrito, sus pedidos y sus apartados con sesión (`/carrito`, `/carrito/pedidos/mis`, `/apartados/mis-apartados`)

El carrito y los pedidos solo se leen: no se crean pedidos ni pagos. La sesión es la de la cuenta de cliente de prueba (secretos `PRUEBAS_CORREO`, `PRUEBAS_CONTRASENA` y `FIREBASE_API_KEY`).

## Preparación: límite de peticiones por IP

El backend limita a **500 peticiones por IP cada 15 minutos** (protección RASP, variable `RASP_RATE_LIMIT_MAX`). Como toda la carga de k6 sale de una sola máquina, con ese límite la prueba habría medido los rechazos 429 del límite y no la capacidad del servidor.

Por eso, solo durante la prueba:

1. Se subió `RASP_RATE_LIMIT_MAX` a 100000 en Render (evidencia 185) y se comprobó en la cabecera `x-ratelimit-limit` de la respuesta.
2. Se corrieron los dos escenarios.
3. Se regresó a 500 (evidencia 187) y se comprobó de nuevo en la cabecera.

En uso normal el límite sigue en 500 por IP, porque cada cliente llega desde su propia conexión.

## Resultados

| Escenario | Usuarios | Duración | Peticiones | 95 % de respuestas | Promedio | Errores | Resultado |
|---|---|---|---|---|---|---|---|
| Criterio | 50 | 3 min | 12,771 (~70/s) | **0.60 s** | 0.28 s | **0 %** | **Pasa** (evidencia 186) |
| Subida por escalones | 25 → 50 → 75 → 100 → 125 → 150 | 6.5 min | 36,261 (~95/s) | 1.94 s | 0.71 s | 0 % | Sin errores; tiempos al límite (evidencia 188) |

Las 6 rutas respondieron 200 en todas las peticiones de los dos escenarios.

En el escenario del criterio la respuesta más lenta fue de 40.8 s: es la primera petición, la que despierta el servidor de Render después de estar sin uso. Las demás quedaron por debajo de 1 s.

## Dónde empieza a fallar

No se encontró un punto de quiebre por **errores**: con 150 usuarios el servidor respondió todas las peticiones.

Sí se ve el límite por **tiempo**. Con 50 usuarios el servidor atendió unas 70 peticiones por segundo; con 150 (el triple) solo unas 95. El servidor se satura alrededor de **95 peticiones por segundo**: a partir de ahí no rechaza peticiones, pero cada cliente espera más. Con todos los escalones juntos, el 95 % de las respuestas quedó en 1.94 s, apenas debajo de los 2 s; por encima de unos **100 usuarios simultáneos** los tiempos pasarían de 2 s.

Es el plan gratuito de Render (una instancia). Para más de 100 clientes al mismo tiempo habría que subir de plan o agregar caché al catálogo.

## Cómo repetirla

```
# En GitHub: Actions → Pruebas de esfuerzo → Run workflow (escenario criterio o quiebre)
# En local, con k6 instalado:
k6 run -e ESCENARIO=criterio -e USUARIOS=50 pruebas/esfuerzo/catalogo.js
k6 run -e ESCENARIO=quiebre -e MAXIMO=150 pruebas/esfuerzo/catalogo.js
```

Antes de correrla hay que subir el límite por IP en Render y regresarlo a 500 al terminar.
