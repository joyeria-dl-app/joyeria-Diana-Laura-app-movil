import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/utils/validaciones.dart';

void main() {
  group('Nombre', () {
    test('Acepta letras con acentos y espacios', () => expect(Validaciones.nombre('Ana Martínez'), isNull));
    test('Rechaza números', () => expect(Validaciones.nombre('Ana 2'), isNotNull));
    test('Rechaza menos de 3 caracteres', () => expect(Validaciones.nombre('An'), isNotNull));
    test('Rechaza espacios al inicio o al final', () => expect(Validaciones.nombre(' Ana'), isNotNull));
  });

  group('Correo', () {
    test('Acepta un correo válido', () => expect(Validaciones.correo('ana.m@correo.com'), isNull));
    test('Rechaza un correo sin dominio', () => expect(Validaciones.correo('ana@correo'), 'Ingresa un correo válido'));
  });

  group('Contraseña', () {
    test('Acepta una que cumple todas las reglas', () => expect(Validaciones.contrasena('Clave1234'), isNull));
    test('Indica qué le falta', () {
      expect(Validaciones.contrasena('clave1234'), 'Falta: mayúscula');
      expect(Validaciones.contrasena('Clave 12'), 'Falta: sin espacios');
    });
    test('Rechaza más de 16 caracteres', () => expect(Validaciones.contrasena('Clave12345678901234'), contains('8 a 16')));
    test('Las reglas se evalúan una por una para mostrarlas en pantalla', () {
      final reglas = Validaciones.reglasContrasena('Clave');
      expect(reglas.where((r) => r.cumple).map((r) => r.texto), ['Mayúscula', 'Minúscula', 'Sin espacios']);
    });
  });

  test('La confirmación debe coincidir', () {
    expect(Validaciones.confirmacion('Clave1234', 'Clave1234'), isNull);
    expect(Validaciones.confirmacion('Clave1235', 'Clave1234'), 'Las contraseñas no coinciden');
  });

  test('La respuesta secreta necesita al menos 2 caracteres', () {
    expect(Validaciones.respuestaSecreta('R'), isNotNull);
    expect(Validaciones.respuestaSecreta('Rosa'), isNull);
  });
}
