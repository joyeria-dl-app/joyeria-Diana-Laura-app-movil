"""Revisa el resultado de las pruebas de la versión anterior (reporte JSON de flutter test).

Falla si se rompe alguna prueba que no esté en .github/regresion-reemplazadas.txt.
Avisa si alguna prueba de esa lista ya pasa, para quitarla.
Uso: python3 revisar_regresion.py <reporte.json> <lista.txt>
"""
import json
import os
import sys

reporte, lista = sys.argv[1], sys.argv[2]

reemplazadas = {}
for linea in open(lista, encoding='utf-8'):
    linea = linea.strip()
    if not linea or linea.startswith('#'):
        continue
    partes = [p.strip() for p in linea.split('|')]
    reemplazadas[(partes[0], partes[1])] = partes[2]

suites, pruebas, resultados = {}, {}, {}
for linea in open(reporte, encoding='utf-8'):
    try:
        e = json.loads(linea)
    except ValueError:
        continue
    if e.get('type') == 'suite':
        suites[e['suite']['id']] = os.path.basename(e['suite'].get('path') or '')
    elif e.get('type') == 'testStart':
        t = e['test']
        pruebas[t['id']] = (suites.get(t['suiteID'], ''), t['name'])
    elif e.get('type') == 'testDone' and not e.get('hidden'):
        resultados[e['testID']] = e['result']

fallas = {pruebas[i] for i, r in resultados.items() if r != 'success' and i in pruebas}
pasan = {pruebas[i] for i, r in resultados.items() if r == 'success' and i in pruebas}
nuevas = sorted(fallas - set(reemplazadas))
esperadas = sorted(fallas & set(reemplazadas))
ya_pasan = sorted(set(reemplazadas) & pasan)

print(f'Pruebas de la versión anterior: {len(resultados)}; pasan {len(pasan)}; fallan {len(fallas)}.')
print(f'Fallan por un cambio intencional (lista de reemplazadas): {len(esperadas)}')
for archivo, nombre in esperadas:
    print(f'  - {archivo}: {nombre} -> {reemplazadas[(archivo, nombre)]}')
for archivo, nombre in ya_pasan:
    print(f'::warning::{archivo}: "{nombre}" ya pasa; se puede quitar de la lista de reemplazadas.')
if not resultados:
    print('::error::No se encontraron resultados en el reporte.')
    sys.exit(1)
if nuevas:
    for archivo, nombre in nuevas:
        print(f'::error::Regresión: {archivo}: "{nombre}" pasaba en la versión anterior y ahora falla.')
    sys.exit(1)
print('Sin regresiones: ninguna prueba que pasaba antes falla fuera de la lista de reemplazadas.')
