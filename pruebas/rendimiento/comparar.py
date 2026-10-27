# Compara las métricas de una corrida de Pruebas de rendimiento con la línea base (#230).
#
# Lee el tamaño del APK (metricas-tamano.json) y los tiempos que rendimiento_test.dart escribe
# con "RENDIMIENTO clave: valor" en el reporte JSON de flutter test. Escribe la tabla en el
# resumen de la corrida y guarda metricas.json con lo medido.
#
# No falla por la línea base: los umbrales ya los revisan el paso del APK y la prueba en el
# emulador. Aquí solo se avisa si una métrica quedó más de 20 % arriba de la línea base, para ver
# si el rendimiento empeora poco a poco aunque siga dentro del umbral.
#
# Uso: python pruebas/rendimiento/comparar.py <carpeta con los resultados> <salida.json>
import json
import os
import re
import sys
from pathlib import Path

carpeta, salida = Path(sys.argv[1]), Path(sys.argv[2])
base = json.loads(Path(__file__).with_name('linea_base.json').read_text(encoding='utf-8'))
medidas = {}

for archivo in carpeta.rglob('metricas-tamano.json'):
    medidas.update(json.loads(archivo.read_text(encoding='utf-8')))

for archivo in carpeta.rglob('rendimiento.json'):
    for linea in archivo.read_text(encoding='utf-8').splitlines():
        try:
            evento = json.loads(linea)
        except json.JSONDecodeError:
            continue
        m = re.search(r'RENDIMIENTO (\w+): ([\d.]+)', str(evento.get('message', '')))
        if m:
            medidas[m.group(1)] = float(m.group(2))

aviso = base['aviso_por_encima_de_la_linea_base']
filas = ['| Métrica | Línea base | Esta corrida | Diferencia | Umbral | Estado |', '|---|---|---|---|---|---|']
for clave, d in base['metricas'].items():
    valor = medidas.get(clave)
    if valor is None:
        filas.append(f"| {d['nombre']} | {d['linea_base']} {d['unidad']} | sin dato | – | < {d['umbral']} {d['unidad']} | no se midió |")
        continue
    cambio = (valor - d['linea_base']) * 100 / d['linea_base']
    if valor >= d['umbral']:
        estado = '**pasa el umbral**'
    elif cambio > aviso:
        estado = f'dentro del umbral, más de {aviso} % arriba de la línea base'
    else:
        estado = 'bien'
    filas.append(f"| {d['nombre']} | {d['linea_base']} {d['unidad']} | {valor:g} {d['unidad']} | {cambio:+.1f} % | < {d['umbral']} {d['unidad']} | {estado} |")

tabla = '\n'.join(['## Rendimiento: comparación con la línea base', '', *filas, '', f"Línea base: {base['origen']}."])
print(tabla)
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as resumen:
        resumen.write(tabla + '\n')
salida.write_text(json.dumps(medidas, indent=2, ensure_ascii=False), encoding='utf-8')
