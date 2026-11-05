import 'package:flutter/services.dart';

// #99: teléfonos con root. Con root el cifrado del Keystore protege menos y el APK se puede
// modificar con más facilidad, así que la app no guarda la sesión ni deja pagar en línea.
// El servidor sigue validando monto y estado del pago (#98); esto es una capa más.

// Se calcula al abrir la app. Las pruebas lo cambian directamente.
bool dispositivoConRoot = false;

// Lo responde MainActivity.kt. Las pruebas lo cambian para simular un teléfono con o sin root.
Future<bool> Function() detectarRoot = () async => await const MethodChannel('joyeria/dispositivo').invokeMethod<bool>('tieneRoot') ?? false;

// Si la detección falla, la app sigue como en un teléfono normal.
Future<bool> revisarRoot() async {
  try {
    dispositivoConRoot = await detectarRoot();
  } on Object {
    dispositivoConRoot = false;
  }
  return dispositivoConRoot;
}

const avisoRoot = 'Este teléfono tiene root. Por seguridad no se guarda tu sesión y no se puede pagar en línea.';
