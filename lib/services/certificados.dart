import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

// Certificate Pinning (#272).
//
// El certificado del backend en Render (onrender.com) lo firma Google Trust Services y Render lo
// renueva cada ~90 días; fijar ese certificado haría que la app dejara de conectarse en cada
// renovación. Por eso se fijan las autoridades raíz que lo firman: el cliente HTTP de la app no
// confía en ninguna otra autoridad del teléfono, así que un certificado de otra autoridad (un proxy
// que intercepta el tráfico o una CA instalada por el usuario) se rechaza.
//
// Antes de usarlas se comprueba que el SHA-256 de cada certificado coincida con el publicado por su
// autoridad; si alguien cambia el texto, la app no confía en nada y no se conecta.
//   GTS Root R4 ............ https://pki.goog/repository/ (válido hasta 2036)
//   GlobalSign Root CA (R1)  https://support.globalsign.com/ca-certificates/root-certificates (hasta 2028;
//                            firma la versión cruzada de GTS Root R4 que envía Render)

class CertificadoFijado {
  const CertificadoFijado(this.nombre, this.sha256, this.pem);
  final String nombre;
  // Huella SHA-256 del certificado (DER), en hexadecimal.
  final String sha256;
  final String pem;
}

const certificadosFijados = [
  CertificadoFijado('GTS Root R4', '349dfa4058c5e263123b398ae795573c4e1313c83fe68f93556cd5e8031b3c7d', '''
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
'''),
  CertificadoFijado('GlobalSign Root CA', 'ebd41040e4bb3ec742c9e381d31ef2a41a48b6685c96e7cef3c1df6cd4331c99', '''
-----BEGIN CERTIFICATE-----
MIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG
A1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv
b3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw
MDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
YWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT
aWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ
jc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp
xy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp
1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG
snUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ
U26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8
9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E
BTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B
AQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz
yj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE
38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP
AbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad
DKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME
HMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==
-----END CERTIFICATE-----
'''),
];

// SHA-256 del certificado en formato DER (lo que se publica como "huella").
String huellaSha256(String pem) {
  final base64 = pem.split('\n').where((l) => l.isNotEmpty && !l.startsWith('-----')).join();
  return sha256.convert(base64Decode(base64)).toString();
}

// Contexto TLS que solo confía en los certificados fijados cuya huella coincide.
SecurityContext contextoFijado([List<CertificadoFijado> fijados = certificadosFijados]) {
  final contexto = SecurityContext(withTrustedRoots: false);
  for (final c in fijados) {
    if (huellaSha256(c.pem) != c.sha256) {
      throw StateError('El certificado fijado ${c.nombre} no coincide con su huella SHA-256');
    }
    contexto.setTrustedCertificatesBytes(utf8.encode(c.pem));
  }
  return contexto;
}

// Cliente HTTP de la app (IOHttpClientAdapter de Dio).
HttpClient clienteConPinning() => HttpClient(context: contextoFijado());
