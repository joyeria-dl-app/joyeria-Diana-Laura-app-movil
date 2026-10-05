// Prueba de esfuerzo del backend que usa la app (pipeline pruebas-esfuerzo.yml).
// Sube la carga poco a poco hasta USUARIOS simultáneos que navegan el catálogo.
import http from 'k6/http';
import { check, sleep } from 'k6';

const API = __ENV.API_URL || 'https://joyeria-diana-laura-nqnq.onrender.com/api';
const USUARIOS = Number(__ENV.USUARIOS || 50);

export const options = {
  stages: [
    { duration: '30s', target: Math.ceil(USUARIOS / 5) },
    { duration: '1m', target: USUARIOS },
    { duration: '1m', target: USUARIOS },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95 % de respuestas en menos de 2 s
    http_req_failed: ['rate<0.01'], // menos del 1 % de errores
  },
};

// Despierta el servidor antes de medir.
export function setup() {
  http.get(`${API}/products/categorias`, { timeout: '90s' });
}

export default function () {
  const categorias = http.get(`${API}/products/categorias`);
  check(categorias, { 'categorías 200': (r) => r.status === 200 });

  const pagina = Math.floor(Math.random() * 4);
  const lista = http.get(`${API}/products/filter?limit=20&offset=${pagina * 20}`);
  check(lista, { 'catálogo 200': (r) => r.status === 200 });

  const piezas = lista.json('data') || [];
  if (piezas.length > 0) {
    const pieza = piezas[Math.floor(Math.random() * piezas.length)];
    const detalle = http.get(`${API}/products/${pieza.id}`);
    check(detalle, { 'detalle 200': (r) => r.status === 200 });
  }
  sleep(1);
}
