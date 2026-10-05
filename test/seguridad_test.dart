import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

// HU-19 · Pruebas de seguridad (#97): las claves no están en el código y la sesión se guarda cifrada.
// La revisión del historial de Git la hace gitleaks en el pipeline de análisis estático.

// Clave de API de Google/Firebase: "AIza" seguido de 35 caracteres.
final _claveGoogle = RegExp(r'AIza[0-9A-Za-z_\-]{35}');

Iterable<File> _archivos(String carpeta, Set<String> extensiones) =>
    Directory(carpeta).listSync(recursive: true).whereType<File>().where((f) => extensiones.any(f.path.endsWith));

void main() {
  group('Sesión cifrada', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('El token y el usuario se guardan en flutter_secure_storage', () async {
      final cifrado = const FlutterSecureStorage();
      final sesion = SecureSessionStorage(cifrado);

      await sesion.guardar('token-123', const Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente'));

      expect(await cifrado.read(key: 'auth_token'), 'token-123');
      expect(await cifrado.read(key: 'auth_usuario'), contains('ana@correo.com'));
      expect(await sesion.leerToken(), 'token-123');
    });

    test('Al cerrar sesión no queda ningún dato guardado', () async {
      final cifrado = const FlutterSecureStorage();
      final sesion = SecureSessionStorage(cifrado);
      await sesion.guardar('token-123', const Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente'));

      await sesion.borrar();

      expect(await cifrado.readAll(), isEmpty);
      expect(await sesion.leerToken(), isNull);
    });

    test('La app no usa almacenamiento sin cifrar (shared_preferences)', () {
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('shared_preferences')));
      for (final archivo in _archivos('lib', {'.dart'})) {
        expect(archivo.readAsStringSync(), isNot(contains('SharedPreferences')), reason: archivo.path);
      }
    });
  });

  group('Claves fuera del código', () {
    test('Ningún archivo de la app contiene una clave de Firebase', () {
      for (final carpeta in ['lib', 'test', 'integration_test', 'android/app/src']) {
        for (final archivo in _archivos(carpeta, {'.dart', '.xml', '.json', '.kt', '.gradle', '.kts'})) {
          expect(_claveGoogle.hasMatch(archivo.readAsStringSync()), isFalse, reason: 'Clave en ${archivo.path}');
        }
      }
    });

    test('La clave y la cuenta de prueba se leen al compilar, no están escritas', () {
      final auth = File('lib/services/auth_service.dart').readAsStringSync();
      expect(auth, contains("String.fromEnvironment('FIREBASE_API_KEY')"));
      for (final prueba in _archivos('integration_test', {'.dart'})) {
        final codigo = prueba.readAsStringSync();
        if (codigo.contains('PRUEBAS_CORREO')) {
          expect(codigo, contains("String.fromEnvironment('PRUEBAS_CORREO')"), reason: prueba.path);
          expect(codigo, contains("String.fromEnvironment('PRUEBAS_CONTRASENA')"), reason: prueba.path);
        }
      }
    });

    test('env.json está ignorado por Git y el ejemplo no trae valores reales', () {
      final ignorados = File('.gitignore').readAsLinesSync().map((l) => l.trim());
      expect(ignorados, contains('env.json'));
      expect(_claveGoogle.hasMatch(File('env.example.json').readAsStringSync()), isFalse);
    });
  });

  group('Configuración de Android', () {
    final manifiesto = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('La sesión no se copia en los respaldos del teléfono', () {
      expect(manifiesto, contains('android:allowBackup="false"'));
    });

    test('La app solo se conecta por HTTPS', () {
      expect(manifiesto, isNot(contains('usesCleartextTraffic="true"')));
      final api = File('lib/services/api_client.dart').readAsStringSync();
      expect(api, contains("defaultValue: 'https://"));
    });
  });
}
