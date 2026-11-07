# Prueba de aceptación #273 · Eliminar mi cuenta (ARCO, cancelación)

**Tarea:** #273 · **Fecha:** 6 de noviembre de 2026 · **Prueba:** `integration_test/eliminar_cuenta_test.dart`

**Criterio de aceptación:** la cuenta de prueba creada para esto deja de poder iniciar sesión y sus datos personales ya no aparecen.

## Qué hace

**Backend** (`DELETE /auth/profile`, joyeria258076-cell/Joyeria-Diana-Laura#10):

- Solo cuentas de cliente. Con pedidos (pendiente, confirmado, en preparación, enviado) o apartados sin terminar responde **409** y no cambia nada.
- En una transacción borra lo que solo sirve a la persona: carrito, favoritos, teléfonos para avisos, comentarios, sesiones, preguntas secretas, códigos MFA y OAuth, solicitudes de cambio, direcciones, cupones y solicitudes de personalización.
- No borra las filas de `usuarios` ni `clientes`: las ventas, los apartados y la auditoría apuntan a ellas y la ley obliga a conservar las ventas. Se **anonimizan** (nombre, correo, teléfono, foto y fecha de nacimiento) y quedan inactivas; las reseñas quedan firmadas como "Cliente".
- Borra la cuenta de Firebase antes de confirmar la transacción: si Firebase falla, se deshace todo.

**App:** "Eliminar mi cuenta" en Mi perfil, debajo de Cerrar sesión. La confirmación explica qué se borra y qué se conserva. Al terminar se olvida la sesión del teléfono, se vacían carrito y favoritos y se regresa al inicio. Si el backend responde 409, se muestra el motivo y la sesión sigue abierta.

## Entorno

| Elemento | Valor |
|---|---|
| Dispositivo | Emulador Android Pixel 8 (API 36) |
| Backend | Render, con el PR #10 desplegado |
| Cuenta | Creada solo para esta prueba con `Backend/_cuenta273.js` (correo verificado en Firebase); usuario 45 |

## Resultados

| Caso | Qué se prueba | Resultado | Evidencia |
|---|---|---|---|
| CA-43 | Mi perfil muestra "Eliminar mi cuenta"; la cuenta tiene un favorito guardado | Pasa | 200 |
| CA-44 | La confirmación explica que se borran los datos y se conservan las compras sin nombre | Pasa | 200a |
| CA-45 | Al confirmar, la cuenta se elimina, el teléfono ya no guarda la sesión y la app vuelve al inicio con "Tu cuenta se eliminó" | Pasa | 200b |
| CA-46 | Con el mismo correo y contraseña ya no puede iniciar sesión ("Correo o contraseña incorrectos") | Pasa | 200c |

**4 de 4 casos pasan.**

## Revisión en la base y en Firebase (evidencia 200d)

Después de la prueba, `node _cuenta273.js revisar` (solo lectura):

| Dato | Resultado |
|---|---|
| Usuario 45 | `nombre = Cuenta eliminada`, `email = eliminado-45@cuenta-eliminada.invalid`, `activo = false`, sin teléfono ni foto |
| Usuarios con el correo original | 0 |
| Carrito, favoritos, teléfonos para avisos, sesiones y preguntas secretas | 0 en todos |
| Cuenta en Firebase | `auth/user-not-found` |

## Pruebas automatizadas

En `test/perfil_flujo_test.dart` (backend simulado): eliminar la cuenta, cancelar sin cambios y el aviso con pedidos o apartados en curso (409) sin perder la sesión. Con ellas pasan 391 pruebas.
