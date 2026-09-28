# App móvil Joyería Diana Laura

Aplicación móvil para los clientes de Joyería Diana Laura, hecha con Flutter. Usa el mismo backend que el sitio web del negocio, así que la cuenta, el carrito y los pedidos son los mismos en la app y en la web.

- **Planeación y seguimiento:** [GitHub Projects](https://github.com/orgs/joyeria-dl-app/projects/1)
- **Versión actual:** [v0.1.0 – Sprint 1](https://github.com/joyeria-dl-app/joyeria-Diana-Laura-app-movil/releases/tag/v0.1.0)

## Equipo

| Integrante | Rol |
|---|---|
| Marcos Uriel Hernández Bautista (@joyeria258076-cell) | Desarrollo e integración con el backend |
| Diana Laura Hernández Martínez (@martinez-Diana) | Diseño y pantallas |

## Tecnologías

- Flutter 3.47.5 y Dart 3.13 (Android)
- `dio` para las peticiones al backend y `provider` para el estado
- `flutter_secure_storage` para guardar la sesión cifrada
- Firebase Authentication (misma cuenta que el sitio web)
- GitHub Actions para la integración continua

## Cómo ejecutar el proyecto

1. Instalar Flutter y tener un emulador o un celular Android conectado.
2. Clonar el repositorio y descargar las dependencias:
   ```
   git clone https://github.com/joyeria-dl-app/joyeria-Diana-Laura-app-movil.git
   cd joyeria-Diana-Laura-app-movil
   flutter pub get
   ```
3. Copiar `env.example.json` como `env.json` y poner la clave pública de Firebase. Este archivo no se sube al repositorio.
4. Ejecutar la app:
   ```
   flutter run --dart-define-from-file=env.json
   ```

Para revisar el código y correr las pruebas: `flutter analyze` y `flutter test`.

## Estructura

```
lib/
├── models/      datos de la app (usuario)
├── providers/   estado compartido (sesión)
├── routes/      rutas de navegación
├── screens/     pantallas
├── services/    comunicación con el backend y Firebase
├── theme/       colores y tipografía
├── utils/       validaciones
└── widgets/     componentes reutilizables
test/            pruebas automáticas
```

## Estrategia de ramas

Seguimos GitFlow:

- `main`: solo versiones estables. Recibe cambios al cerrar cada sprint.
- `develop`: rama por defecto; reúne lo terminado durante el sprint.
- `feature/...`: una rama por tarea, creada a partir de `develop` (por ejemplo `feature/hu05-pantalla-registro`).

Reglas:

- `main` y `develop` están protegidas: no se puede subir código directamente; todo entra por Pull Request.
- Cada Pull Request debe pasar la verificación de GitHub Actions (`flutter analyze` y `flutter test`) antes de integrarse.
- La descripción del Pull Request incluye `Closes #N` para cerrar su tarea del tablero.
- Cada integrante trabaja sus tareas con su propia cuenta.

## Versionamiento

Usamos versionamiento semántico (`MAYOR.MENOR.PARCHE`). Al cerrar cada sprint se integra `develop` en `main`, se crea una etiqueta y se publica en [Releases](https://github.com/joyeria-dl-app/joyeria-Diana-Laura-app-movil/releases):

| Versión | Sprint | Contenido |
|---|---|---|
| v0.1.0 | Sprint 1 | Base de la app, inicio de sesión, registro y diseño visual |
| v0.2.0 | Sprint 2 | Catálogo, detalle de pieza, carrito y favoritos |
| v0.3.0 | Sprint 3 | Apartado o compra, pago con Mercado Pago y personalización |
| v1.0.0 | Sprint 4 | Perfil, notificaciones, zonas de entrega y versión en pruebas internas de Google Play |

La versión `1.0.0` corresponde a la app completa. Las correcciones urgentes entre sprints aumentan el último número (por ejemplo `v0.1.1`).
