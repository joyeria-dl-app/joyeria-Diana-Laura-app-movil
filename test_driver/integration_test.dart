// TIPO: apoyo (no es prueba)
// ALCANCE: permite correr las pruebas de integration_test con flutter drive en modo perfil (#151)
// EJECUCIÓN: flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/<prueba>.dart
// DATOS: ninguno

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
