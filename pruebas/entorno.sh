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
# Los avisos se leen de la salida de flutter test y también del archivo entorno_pasos.txt
# que la prueba escribe dentro de la app (se lee con adb run-as): al volver a abrir la app
# desde segundo plano, la salida de flutter test a veces deja de traer los mensajes de la
# app (#202). Cada paso se aplica una sola vez.
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

HECHOS=$(mktemp -d)

restaurar() {
  adb_ shell cmd connectivity airplane-mode disable > /dev/null 2>&1
  adb_ emu gsm cancel "$NUMERO" > /dev/null 2>&1
  adb_ emu power ac on > /dev/null 2>&1
  adb_ emu power status charging > /dev/null 2>&1
  adb_ emu power capacity 100 > /dev/null 2>&1
}
terminar() {
  [ -n "$LECTOR" ] && { pkill -P "$LECTOR" > /dev/null 2>&1; kill "$LECTOR" > /dev/null 2>&1; }
  restaurar
  rm -rf "$HECHOS"
}
trap terminar EXIT
restaurar

# Aplica la situación que pide la línea. Devuelve sin hacer nada si ese aviso ya se atendió.
aplicar() {
  local linea=$1 aviso
  aviso=$(printf '%s' "$linea" | grep -oE 'ENTORNO (PASO [a-z_]+|CE-0[0-9] Pasa)') || return 0
  mkdir "$HECHOS/${aviso// /_}" 2> /dev/null || return 0
  case "$aviso" in
      "ENTORNO PASO bateria")
        adb_ emu power ac off > /dev/null
        adb_ emu power status discharging > /dev/null
        adb_ emu power capacity 5 > /dev/null
        echo "ENTORNO adb: $(adb_ shell dumpsys battery | grep -E 'level|AC powered' | tr -s ' \r\n' ' ')"
        sleep 3
        captura 1_bateria_baja
        ;;
      "ENTORNO CE-01 Pasa")
        captura 2_bateria_baja_carrito
        ;;
      "ENTORNO PASO llamada")
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
      "ENTORNO CE-02 Pasa")
        captura 5_despues_de_la_llamada
        ;;
      "ENTORNO PASO segundo_plano")
        adb_ shell input keyevent KEYCODE_HOME
        echo "ENTORNO adb: botón Inicio, la app pasa a segundo plano"
        sleep 6
        captura 6_segundo_plano
        adb_ shell monkey -p "$PAQUETE" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
        echo "ENTORNO adb: se vuelve a abrir la app"
        ;;
      "ENTORNO CE-03 Pasa")
        captura 7_de_regreso
        ;;
      "ENTORNO PASO sin_senal")
        adb_ shell cmd connectivity airplane-mode enable > /dev/null
        echo "ENTORNO adb: modo avión activado"
        ;;
      "ENTORNO CE-04 Pasa")
        captura 8_sin_senal
        ;;
      "ENTORNO PASO con_senal")
        adb_ shell cmd connectivity airplane-mode disable > /dev/null
        echo "ENTORNO adb: modo avión desactivado"
        ;;
      "ENTORNO CE-05 Pasa")
        captura 9_con_senal
        ;;
  esac
}

# Lector de entorno_pasos.txt (respaldo cuando la salida de flutter test se corta).
(
  while sleep 1; do
    adb_ shell "run-as $PAQUETE sh -c 'cat \$(find . -name entorno_pasos.txt 2> /dev/null) 2> /dev/null'" 2> /dev/null |
      tr -d '' | while IFS= read -r linea; do aplicar "$linea"; done
  done
) &
LECTOR=$!

flutter test integration_test/entorno_test.dart --dart-define-from-file=env.json -d "$DISPOSITIVO" --reporter expanded "$@" 2>&1 |
  while IFS= read -r linea; do
    echo "$linea"
    aplicar "$linea"
  done
