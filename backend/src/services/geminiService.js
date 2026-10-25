const { GoogleGenAI, ThinkingLevel } = require('@google/genai');

const MODELOS_POR_DEFECTO = [
  'models/gemini-3.8-flash',
  'models/gemini-3.6-flash',
  'models/gemini-3.5-flash-lite',
  'models/gemini-3.1-flash-lite',
];

const MENSAJE_IA_SATURADA =
  'La inteligencia artificial está muy solicitada en este momento. Espera un par de minutos e inténtalo de nuevo.';

const entero = (valor, defecto) => {
  const n = parseInt(valor, 10);
  return Number.isFinite(n) && n > 0 ? n : defecto;
};

const TIMEOUT_MODELO_MS = entero(process.env.GEMINI_TIMEOUT_MS, 120000);
const PRESUPUESTO_MS = entero(process.env.GEMINI_PRESUPUESTO_MS, 240000);
const ESPERA_MAXIMA_MS = entero(process.env.GEMINI_ESPERA_MAX_MS, 20000);
const RONDAS_MAXIMAS = entero(process.env.GEMINI_RONDAS, 3);
const MAX_SIMULTANEAS = entero(process.env.GEMINI_MAX_SIMULTANEAS, 24);
const ESPERA_COLA_MS = entero(process.env.GEMINI_ESPERA_COLA_MS, 90000);

const BLOQUEO_CUOTA_MS = 60 * 1000;
const BLOQUEO_CUOTA_DIARIA_MS = 60 * 60 * 1000;
const BLOQUEO_LLAVE_INVALIDA_MS = 6 * 60 * 60 * 1000;
const BLOQUEO_MODELO_INEXISTENTE_MS = 30 * 60 * 1000;
const BLOQUEO_SATURADO_MS = 20 * 1000;
const BLOQUEO_TIEMPO_MS = 15 * 1000;
const BLOQUEO_DESCONOCIDO_MS = 10 * 1000;

class IANoDisponibleError extends Error {
  constructor(mensaje = MENSAJE_IA_SATURADA, causa = null) {
    super(mensaje);
    this.name = 'IANoDisponibleError';
    this.codigo = 'IA_NO_DISPONIBLE';
    this.causa = causa;
  }
}

const separarLista = (valor) =>
  String(valor || '')
    .split(/[\s,;]+/)
    .map((s) => s.trim())
    .filter(Boolean);

const cargarLlaves = () => {
  const numeradas = Object.keys(process.env)
    .map((nombre) => {
      const m = /^GEMINI_API_KEY_(\d+)$/.exec(nombre);
      return m ? { orden: parseInt(m[1], 10), valor: process.env[nombre] } : null;
    })
    .filter(Boolean)
    .sort((a, b) => a.orden - b.orden)
    .map((x) => x.valor);

  const todas = [
    ...numeradas,
    ...separarLista(process.env.GEMINI_API_KEYS),
    process.env.GEMINI_API_KEY,
    process.env.GOOGLE_API_KEY,
    process.env.OPENAI_API_KEY,
  ]
    .map((k) => (typeof k === 'string' ? k.trim() : ''))
    .filter(Boolean);

  return [...new Set(todas)];
};

const cargarModelos = () => {
  const lista = separarLista(process.env.GEMINI_MODELOS);
  const modelos = lista.length ? lista : MODELOS_POR_DEFECTO;
  return [...new Set(modelos.map((m) => (m.startsWith('models/') ? m : `models/${m}`)))];
};

const LLAVES = cargarLlaves();
const MODELOS = cargarModelos();
const clientes = LLAVES.map((apiKey) => new GoogleGenAI({ apiKey }));

const enCurso = LLAVES.map(() => 0);
let activas = 0;
const cola = [];

const tomarTurno = (limite) =>
  new Promise((resolve, reject) => {
    if (activas < MAX_SIMULTANEAS) {
      activas++;
      resolve();
      return;
    }
    const espera = Math.max(Math.min(limite - Date.now(), ESPERA_COLA_MS), 0);
    const pendiente = { resolve, temporizador: null };
    pendiente.temporizador = setTimeout(() => {
      const i = cola.indexOf(pendiente);
      if (i >= 0) cola.splice(i, 1);
      reject(new IANoDisponibleError());
    }, espera);
    cola.push(pendiente);
  });

const soltarTurno = () => {
  const siguiente = cola.shift();
  if (siguiente) {
    clearTimeout(siguiente.temporizador);
    siguiente.resolve();
  } else {
    activas = Math.max(activas - 1, 0);
  }
};

const bloqueosPar = new Map();
const bloqueosLlave = new Map();
const bloqueosModelo = new Map();
let turno = 0;

if (!LLAVES.length) {
  console.warn('[Gemini] No hay API keys configuradas (GEMINI_API_KEY_1, GEMINI_API_KEY_2, ...).');
} else {
  console.log(`[Gemini] Cascada lista: ${LLAVES.length} llave(s) x ${MODELOS.length} modelo(s).`);
}

const ahora = () => Date.now();
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
const clavePar = (llave, modelo) => `${llave}|${modelo}`;

const bloqueadoHasta = (llave, modelo) =>
  Math.max(
    bloqueosPar.get(clavePar(llave, modelo)) || 0,
    bloqueosLlave.get(llave) || 0,
    bloqueosModelo.get(modelo) || 0
  );

const bloquear = (mapa, clave, ms) => {
  const hasta = ahora() + ms;
  if ((mapa.get(clave) || 0) < hasta) mapa.set(clave, hasta);
};

const extraerEsperaMs = (texto) => {
  const a = /"retryDelay"\s*:\s*"(\d+(?:\.\d+)?)s"/i.exec(texto);
  if (a) return Math.ceil(parseFloat(a[1]) * 1000);
  const b = /retry in\s+(\d+(?:\.\d+)?)\s*s/i.exec(texto);
  if (b) return Math.ceil(parseFloat(b[1]) * 1000);
  return null;
};

const clasificarError = (err) => {
  const status = Number(err && err.status) || 0;
  const texto = String((err && err.message) || err || '');
  const nombre = String((err && err.name) || '');

  if (nombre === 'AbortError' || nombre === 'TimeoutError' || /aborted|timed? ?out/i.test(texto)) {
    return { tipo: 'tiempo' };
  }
  if (status === 429 || /RESOURCE_EXHAUSTED|quota|rate.?limit|too many requests/i.test(texto)) {
    const diaria = /per.?day|PerDay|daily/i.test(texto);
    const espera = extraerEsperaMs(texto);
    return {
      tipo: 'cuota',
      esperaMs: diaria ? BLOQUEO_CUOTA_DIARIA_MS : Math.max(espera || BLOQUEO_CUOTA_MS, 5000),
    };
  }
  if (status === 401 || status === 403 || /API_KEY_INVALID|API key not valid|PERMISSION_DENIED|API_KEY_.*EXPIRED/i.test(texto)) {
    return { tipo: 'llave' };
  }
  if (status === 404 || /is not found|not supported for generateContent|NOT_FOUND/i.test(texto)) {
    return { tipo: 'modelo' };
  }
  if (status === 400 || /INVALID_ARGUMENT/i.test(texto)) {
    return { tipo: 'peticion', thinking: /thinking/i.test(texto) };
  }
  if (status >= 500 || /UNAVAILABLE|overloaded|INTERNAL|DEADLINE_EXCEEDED|fetch failed|ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|socket hang up/i.test(texto)) {
    return { tipo: 'saturado' };
  }
  return { tipo: 'desconocido' };
};

const aplicarBloqueo = (llave, modelo, info) => {
  switch (info.tipo) {
    case 'cuota':
      bloquear(bloqueosPar, clavePar(llave, modelo), info.esperaMs);
      break;
    case 'llave':
      bloquear(bloqueosLlave, llave, BLOQUEO_LLAVE_INVALIDA_MS);
      break;
    case 'modelo':
      bloquear(bloqueosModelo, modelo, BLOQUEO_MODELO_INEXISTENTE_MS);
      break;
    case 'saturado':
      bloquear(bloqueosPar, clavePar(llave, modelo), BLOQUEO_SATURADO_MS);
      break;
    case 'tiempo':
      bloquear(bloqueosPar, clavePar(llave, modelo), BLOQUEO_TIEMPO_MS);
      break;
    case 'peticion':
      break;
    default:
      bloquear(bloqueosPar, clavePar(llave, modelo), BLOQUEO_DESCONOCIDO_MS);
  }
};

const candidatosDisponibles = () => {
  const inicio = turno++ % Math.max(LLAVES.length, 1);
  const t = ahora();
  const orden = LLAVES.map((_, k) => (inicio + k) % LLAVES.length).sort((a, b) => enCurso[a] - enCurso[b]);
  const lista = [];
  for (const modelo of MODELOS) {
    for (const llave of orden) {
      if (bloqueadoHasta(llave, modelo) <= t) lista.push({ llave, modelo });
    }
  }
  return lista;
};

const proximoDesbloqueo = () => {
  let minimo = Infinity;
  for (const modelo of MODELOS) {
    for (let llave = 0; llave < LLAVES.length; llave++) {
      minimo = Math.min(minimo, bloqueadoHasta(llave, modelo));
    }
  }
  return minimo;
};

const llamar = async ({ llave, modelo, contents, config, thinking, timeoutMs }) => {
  enCurso[llave]++;
  try {
    return await clientes[llave].models.generateContent({
      model: modelo,
      contents,
      config: {
        ...config,
        abortSignal: AbortSignal.timeout(timeoutMs),
        ...(thinking ? { thinkingConfig: { thinkingLevel: thinking } } : {}),
      },
    });
  } finally {
    enCurso[llave]--;
  }
};

const generarContenido = async (opciones) => {
  if (!LLAVES.length) throw new IANoDisponibleError();
  const limite = ahora() + (opciones.presupuestoMs || PRESUPUESTO_MS);
  await tomarTurno(limite);
  try {
    return await ejecutarCascada({ ...opciones, limite });
  } finally {
    soltarTurno();
  }
};

const ejecutarCascada = async ({
  contents,
  config = {},
  thinking = null,
  procesar = (texto) => texto,
  limite,
  etiqueta = 'IA',
}) => {
  let ultimoError = null;

  for (let ronda = 1; ronda <= RONDAS_MAXIMAS; ronda++) {
    const candidatos = candidatosDisponibles();

    for (const { llave, modelo } of candidatos) {
      if (bloqueadoHasta(llave, modelo) > ahora()) continue;

      let usarThinking = thinking;
      for (let intento = 0; intento < 2; intento++) {
        const restante = limite - ahora();
        if (restante < 3000) throw new IANoDisponibleError(MENSAJE_IA_SATURADA, ultimoError);

        try {
          const inicio = ahora();
          const respuesta = await llamar({
            llave,
            modelo,
            contents,
            config,
            thinking: usarThinking,
            timeoutMs: Math.min(TIMEOUT_MODELO_MS, restante),
          });
          const texto = respuesta && respuesta.text;
          if (!texto) {
            ultimoError = new Error('Respuesta vacía');
            break;
          }
          let valor;
          try {
            valor = procesar(texto);
          } catch (errProcesar) {
            ultimoError = errProcesar;
            console.warn(`[Gemini] ${etiqueta}: ${modelo} (llave #${llave + 1}) devolvió un formato inválido.`);
            break;
          }
          console.log(`[Gemini] ${etiqueta}: ${modelo} (llave #${llave + 1}) respondió en ${ahora() - inicio} ms`);
          return valor;
        } catch (err) {
          ultimoError = err;
          const info = clasificarError(err);
          console.warn(
            `[Gemini] ${etiqueta}: falló ${modelo} (llave #${llave + 1}) -> ${info.tipo}${info.esperaMs ? ` ${Math.round(info.esperaMs / 1000)}s` : ''}`
          );
          if (info.tipo === 'peticion' && usarThinking) {
            usarThinking = null;
            continue;
          }
          aplicarBloqueo(llave, modelo, info);
          break;
        }
      }
    }

    if (ronda === RONDAS_MAXIMAS) break;

    const espera = proximoDesbloqueo() - ahora();
    const restante = limite - ahora();
    if (!Number.isFinite(espera) || espera > ESPERA_MAXIMA_MS || espera + 3000 > restante) break;
    await dormir(Math.max(espera, 0) + 300 + Math.floor(Math.random() * 700));
  }

  throw new IANoDisponibleError(MENSAJE_IA_SATURADA, ultimoError);
};

const generarJSON = (prompt, schema, { thinking = ThinkingLevel.LOW, etiqueta = 'JSON', presupuestoMs } = {}) =>
  generarContenido({
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      ...(schema ? { responseSchema: schema } : {}),
    },
    thinking,
    procesar: (texto) => JSON.parse(texto),
    etiqueta,
    presupuestoMs,
  });

const estadoCascada = () => {
  const t = ahora();
  return {
    activas,
    enCola: cola.length,
    porLlave: [...enCurso],
    llaves: LLAVES.length,
    modelos: MODELOS,
    disponibles: candidatosDisponibles().length,
    bloqueadas: LLAVES.map((_, i) =>
      MODELOS.filter((m) => bloqueadoHasta(i, m) > t).map((m) => ({
        modelo: m,
        segundos: Math.ceil((bloqueadoHasta(i, m) - t) / 1000),
      }))
    ),
  };
};

module.exports = {
  ThinkingLevel,
  generarContenido,
  generarJSON,
  estadoCascada,
  IANoDisponibleError,
  MENSAJE_IA_SATURADA,
};