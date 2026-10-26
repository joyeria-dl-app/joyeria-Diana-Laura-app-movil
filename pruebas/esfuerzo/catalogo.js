// Prueba de esfuerzo del backend que usa la app (pipeline pruebas-esfuerzo.yml, tarea #149).
// Recorre lo mismo que un cliente en la app: catálogo, detalle, carrito y pedidos con sesión.
//
// ESCENARIO=criterio (por defecto): sube a USUARIOS simultáneos y se queda ahí; debe cumplir
//   95 % de respuestas en menos de 2 s y menos del 1 % de errores.
// ESCENARIO=quiebre: sube por escalones hasta MAXIMO usuarios para ver dónde empiezan a fallar
//   los tiempos; no tiene umbrales que detengan la prueba, se lee el resultado por escalón.
//
// RECUPERACIÓN (#230): al terminar la carga, 2 usuarios siguen pidiendo el catálogo durante 1 minuto.
//   El servidor se considera recuperado si en esa fase el 95 % de las respuestas tarda menos de 1 s y
//   no hay errores; si no, la prueba falla aunque la carga haya pasado. Aplica a los dos escenarios.
//
// Entorno: API_URL apunta al backend de Render (por defecto) o al backend levantado dentro de GitHub
// Actions con una base de datos propia (pipeline, trabajo "aislado"), que no toca producción.
//
// El carrito y los pedidos solo se leen (no se crean pedidos ni pagos). La sesión es la de la
// cuenta de prueba (PRUEBAS_CORREO / PRUEBAS_CONTRASENA) y se abre una vez en setup().
//
// Importante: el backend limita a 500 peticiones por IP cada 15 minutos (RASP_RATE_LIMIT_MAX).
// Como toda la carga sale de una sola máquina, antes de la prueba se sube ese límite en Render
// y al terminar se regresa a 500 (ver pruebas/esfuerzo_sprint3.md).
import http from 'k6/http';
import { check, group, sleep } from 'k6';

const API = __ENV.API_URL || 'https://joyeria-diana-laura-nqnq.onrender.com/api';
const ESCENARIO = __ENV.ESCENARIO || 'criterio';
const USUARIOS = Number(__ENV.USUARIOS || 50);
const MAXIMO = Number(__ENV.MAXIMO || 150);

// Duración total de las etapas de carga, para que la recuperación empiece justo al terminar.
const segundos = (d) => Number.parseInt(d, 10) * (d.endsWith('m') ? 60 : 1);
const duracion = (stages) => stages.reduce((total, e) => total + segundos(e.duration), 0);

const escenarios = {
  criterio: {
    executor: 'ramping-vus',
    tags: { fase: 'carga' },
    stages: [
      { duration: '30s', target: Math.ceil(USUARIOS / 5) },
      { duration: '1m', target: USUARIOS },
      { duration: '1m', target: USUARIOS },
      { duration: '30s', target: 0 },
    ],
  },
  quiebre: {
    executor: 'ramping-vus',
    tags: { fase: 'carga' },
    stages: [25, 50, 75, 100, 125, MAXIMO]
      .filter((n, i, lista) => n <= MAXIMO && lista.indexOf(n) === i)
      .flatMap((n) => [
        { duration: '20s', target: n },
        { duration: '40s', target: n },
      ])
      .concat([{ duration: '20s', target: 0 }]),
  },
};

const recuperacion = {
  executor: 'constant-vus',
  vus: 2,
  duration: '1m',
  startTime: `${duracion(escenarios[ESCENARIO].stages)}s`,
  tags: { fase: 'recuperacion' },
};

export const options = {
  scenarios: { [ESCENARIO]: escenarios[ESCENARIO], recuperacion },
  thresholds: {
    ...(ESCENARIO === 'criterio'
      ? {
          'http_req_duration{fase:carga}': ['p(95)<2000'], // 95 % de respuestas en menos de 2 s
          'http_req_failed{fase:carga}': ['rate<0.01'], // menos del 1 % de errores
        }
      : {}),
    // Recuperación: después de la carga el servidor vuelve a responder como sin carga.
    'http_req_duration{fase:recuperacion}': ['p(95)<1000'],
    'http_req_failed{fase:recuperacion}': ['rate==0'],
  },
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'max'],
};

// Despierta el servidor y abre la sesión de la cuenta de prueba (Firebase y luego el backend).
export function setup() {
  const prueba = http.get(`${API}/products/categorias`, { timeout: '90s' });
  console.log(`Límite por IP del backend: ${prueba.headers['X-Ratelimit-Limit']}`);

  const correo = __ENV.PRUEBAS_CORREO;
  const contrasena = __ENV.PRUEBAS_CONTRASENA;
  const clave = __ENV.FIREBASE_API_KEY;
  if (!correo || !contrasena || !clave) {
    console.warn('Sin PRUEBAS_CORREO, PRUEBAS_CONTRASENA o FIREBASE_API_KEY: solo se prueba el catálogo');
    return { token: null };
  }
  const firebase = http.post(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${clave}`,
    JSON.stringify({ email: correo, password: contrasena, returnSecureToken: true }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  const login = http.post(`${API}/auth/login/movil`, JSON.stringify({ idToken: firebase.json('idToken') }), {
    headers: { 'Content-Type': 'application/json' },
  });
  const token = login.json('data.token');
  if (!token) throw new Error(`No se pudo iniciar sesión con la cuenta de prueba (${login.status})`);
  return { token };
}

export default function (datos) {
  group('catálogo', () => {
    const categorias = http.get(`${API}/products/categorias`, { tags: { endpoint: 'categorias' } });
    check(categorias, { 'categorías 200': (r) => r.status === 200 });

    const pagina = Math.floor(Math.random() * 4);
    const lista = http.get(`${API}/products/filter?limit=20&offset=${pagina * 20}`, { tags: { endpoint: 'catalogo' } });
    check(lista, { 'catálogo 200': (r) => r.status === 200 });

    const piezas = lista.status === 200 ? lista.json('data') || [] : [];
    if (piezas.length > 0) {
      const pieza = piezas[Math.floor(Math.random() * piezas.length)];
      const detalle = http.get(`${API}/products/${pieza.id}`, { tags: { endpoint: 'detalle' } });
      check(detalle, { 'detalle 200': (r) => r.status === 200 });
    }
  });

  if (datos.token) {
    const sesion = { headers: { Authorization: `Bearer ${datos.token}` } };
    group('carrito y pedidos', () => {
      const carrito = http.get(`${API}/carrito`, { ...sesion, tags: { endpoint: 'carrito' } });
      check(carrito, { 'carrito 200': (r) => r.status === 200 });

      const pedidos = http.get(`${API}/carrito/pedidos/mis`, { ...sesion, tags: { endpoint: 'pedidos' } });
      check(pedidos, { 'pedidos 200': (r) => r.status === 200 });

      const apartados = http.get(`${API}/apartados/mis-apartados`, { ...sesion, tags: { endpoint: 'apartados' } });
      check(apartados, { 'apartados 200': (r) => r.status === 200 });
    });
  }
  sleep(1);
}
