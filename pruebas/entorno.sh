#!/usr/bin/env bash
# Pruebas del entorno: corre integration_test/entorno_test.dart y, cuando la prueba avisa
# con "ENTORNO PASO <caso>", aplica la situación en el emulador con adb:
#   bateria    batería al 5% y sin cargador
#   llamada    llamada entrante, se contesta y se cuelga
#   segundo_plano  botón Inicio y, 6 s después, se vuelve a abrir la app
#   sin_senal  modo avión
#   con_senal  se quita el modo avión
# Al terminar (pase o falle) deja el emulador como estaba.
#
# Uso: bash pruebas/entorno.sh
# Variables opcionales: DISPOSITIVO (emulator-5554), CAPTURAS (carpeta para guardar
# capturas de pantalla de cada caso).
set -o pipefail

DISPOSITIVO=${DISPOSITIVO:-emulator-5554}
NUMERO=5551234567
PAQUETE=com.joyeriadianalaura.joyeria_diana_laura
adb_() { adb -s "$DISPOSITIVO" "$@"; }

captura() {
  [ -n "$CAPTURAS" ] || return 0
  mkdir -p "$CAPTURAS"
  adb_ exec-out screencap -p > "$CAPTURAS/$1.png"
}

restaurar() {
  adb_ shell cmd connectivity airplane-mode disable > /dev/null 2>&1
  adb_ emu gsm cancel "$NUMERO" > /dev/null 2>&1
  adb_ emu power ac on > /dev/null 2>&1
  adb_ emu power status charging > /dev/null 2>&1
  adb_ emu power capacity 100 > /dev/null 2>&1
}
trap restaurar EXIT
restaurar

flutter test integration_test/entorno_test.dart --dart-define-from-file=env.json -d "$DISPOSITIVO" --reporter expanded "$@" 2>&1 |
  while IFS= read -r linea; do
    echo "$linea"
    case "$linea" in
      *"ENTORNO PASO bateria"*)
        adb_ emu power ac off > /dev/null
        adb_ emu power status discharging > /dev/null
        adb_ emu power capacity 5 > /dev/null
        echo "ENTORNO adb: $(adb_ shell dumpsys battery | grep -E 'level|AC powered' | tr -s ' \r\n' ' ')"
        sleep 3
        captura 1_bateria_baja
        ;;
      *"ENTORNO CE-01 Pasa"*)
        captura 2_bateria_baja_carrito
        ;;
      *"ENTORNO PASO llamada"*)
        adb_ emu gsm call "$NUMERO" > /dev/null
        echo "ENTORNO adb: llamada entrante de $NUMERO"
        sleep 4
        captura 3_llamada_entrante
        adb_ emu gsm accept "$NUMERO" > /dev/null
        sleep 5
        captura 4_llamada_en_curso
        adb_ emu gsm cancel "$NUMERO" > /dev/null
        echo "ENTORNO adb: llamada terminada"
        ;;
      *"ENTORNO CE-02 Pasa"*)
        captura 5_despues_de_la_llamada
        ;;
      *"ENTORNO PASO segundo_plano"*)
        adb_ shell input keyevent KEYCODE_HOME
        echo "ENTORNO adb: botón Inicio, la app pasa a segundo plano"
        sleep 6
        captura 6_segundo_plano
        adb_ shell monkey -p "$PAQUETE" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
        echo "ENTORNO adb: se vuelve a abrir la app"
        ;;
      *"ENTORNO CE-03 Pasa"*)
        captura 7_de_regreso
        ;;
      *"ENTORNO PASO sin_senal"*)
        adb_ shell cmd connectivity airplane-mode enable > /dev/null
        echo "ENTORNO adb: modo avión activado"
        ;;
      *"ENTORNO CE-04 Pasa"*)
        captura 8_sin_senal
        ;;
      *"ENTORNO PASO con_senal"*)
        adb_ shell cmd connectivity airplane-mode disable > /dev/null
        echo "ENTORNO adb: modo avión desactivado"
        ;;
      *"ENTORNO CE-05 Pasa"*)
        captura 9_con_senal
        ;;
    esac
  done
