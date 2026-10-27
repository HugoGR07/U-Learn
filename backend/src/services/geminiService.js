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

const TIMEOUT_MODELO_MS = entero(process.env.GEMINI_TIMEOUT_MS, 60000);
const PRESUPUESTO_MS = entero(process.env.GEMINI_PRESUPUESTO_MS, 90000);
const ESPERA_MAXIMA_MS = entero(process.env.GEMINI_ESPERA_MAX_MS, 30000);
const RONDAS_MAXIMAS = entero(process.env.GEMINI_RONDAS, 3);
const MAX_SIMULTANEAS = entero(process.env.GEMINI_MAX_SIMULTANEAS, 32);
const ESPERA_COLA_MS = entero(process.env.GEMINI_ESPERA_COLA_MS, 30000);
const RESPALDO_MS = entero(process.env.GEMINI_RESPALDO_MS, 60000);
const MAX_PARALELAS = entero(process.env.GEMINI_MAX_PARALELAS, 2);
const RPM_POR_MODELO = entero(process.env.GEMINI_RPM, 10);
const VENTANA_RPM_MS = 60 * 1000;
const LENTO_MS = entero(process.env.GEMINI_LENTO_MS, 45000);
const CASTIGO_LENTO_MS = 5 * 60 * 1000;

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
const modelosSinThinking = new Set();
const usos = new Map();
const modelosLentos = new Map();

const marcarLento = (modelo) => modelosLentos.set(modelo, Date.now() + CASTIGO_LENTO_MS);
const esLento = (modelo) => (modelosLentos.get(modelo) || 0) > Date.now();
let turno = 0;

if (!LLAVES.length) {
  console.warn('[Gemini] No hay API keys configuradas (GEMINI_API_KEY_1, GEMINI_API_KEY_2, ...).');
} else {
  console.log(`[Gemini] Cascada lista: ${LLAVES.length} llave(s) x ${MODELOS.length} modelo(s).`);
}

const ahora = () => Date.now();
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
const clavePar = (llave, modelo) => `${llave}|${modelo}`;

const liberaLimite = (llave, modelo) => {
  const lista = usos.get(clavePar(llave, modelo));
  if (!lista) return 0;
  const t = ahora();
  while (lista.length && lista[0] <= t - VENTANA_RPM_MS) lista.shift();
  return lista.length >= RPM_POR_MODELO ? lista[0] + VENTANA_RPM_MS : 0;
};

const registrarUso = (llave, modelo) => {
  const clave = clavePar(llave, modelo);
  if (!usos.has(clave)) usos.set(clave, []);
  usos.get(clave).push(ahora());
};

const bloqueadoHasta = (llave, modelo) =>
  Math.max(
    bloqueosPar.get(clavePar(llave, modelo)) || 0,
    bloqueosLlave.get(llave) || 0,
    bloqueosModelo.get(modelo) || 0,
    liberaLimite(llave, modelo)
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
  const ordenModelos = [...MODELOS.filter((m) => !esLento(m)), ...MODELOS.filter(esLento)];
  for (const modelo of ordenModelos) {
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

const senalCombinada = (controlador, timeoutMs) => {
  const tiempo = AbortSignal.timeout(Math.max(timeoutMs, 1000));
  if (typeof AbortSignal.any === 'function') return AbortSignal.any([controlador.signal, tiempo]);
  tiempo.addEventListener('abort', () => controlador.abort(tiempo.reason), { once: true });
  return controlador.signal;
};

const llamar = async ({ llave, modelo, contents, config, thinking, timeoutMs, controlador }) => {
  enCurso[llave]++;
  try {
    return await clientes[llave].models.generateContent({
      model: modelo,
      contents,
      config: {
        ...config,
        abortSignal: senalCombinada(controlador, timeoutMs),
        ...(thinking ? { thinkingConfig: { thinkingLevel: thinking } } : {}),
      },
    });
  } finally {
    enCurso[llave]--;
  }
};

const generarContenido = async (opciones) => {
  if (!LLAVES.length) throw new IANoDisponibleError();
  const presupuesto = opciones.presupuestoMs || PRESUPUESTO_MS;
  if (presupuesto < 3000) throw new IANoDisponibleError();
  const limite = ahora() + presupuesto;
  await tomarTurno(limite);
  try {
    return await ejecutarCascada({ ...opciones, limite });
  } finally {
    soltarTurno();
  }
};

const ejecutarCascada = ({
  contents,
  config = {},
  thinking = null,
  procesar = (texto) => texto,
  limite,
  etiqueta = 'IA',
  timeoutMs = TIMEOUT_MODELO_MS,
  respaldoMs = RESPALDO_MS,
  maxParalelas = MAX_PARALELAS,
}) =>
  new Promise((resolve, reject) => {
    let terminado = false;
    let ultimoError = null;
    let ronda = 1;
    let intentados = new Set();
    let temporizadorRespaldo = null;
    let temporizadorLimite = null;
    let temporizadorEspera = null;
    const enVuelo = new Map();
    const inicioCascada = ahora();

    const limpiar = () => {
      terminado = true;
      clearTimeout(temporizadorRespaldo);
      clearTimeout(temporizadorLimite);
      clearTimeout(temporizadorEspera);
      for (const c of enVuelo.values()) c.abort();
      enVuelo.clear();
    };

    const fallar = () => {
      if (terminado) return;
      limpiar();
      reject(new IANoDisponibleError(MENSAJE_IA_SATURADA, ultimoError));
    };

    const exito = (valor) => {
      if (terminado) return;
      limpiar();
      resolve(valor);
    };

    temporizadorLimite = setTimeout(() => {
      if (terminado) return;
      const segundos = Math.round((ahora() - inicioCascada) / 1000);
      console.warn(
        `[Gemini] ${etiqueta}: se agotó el tiempo disponible (${segundos}s)${enVuelo.size ? `; se cancelaron ${enVuelo.size} solicitud(es) en curso` : ''}.`
      );
      if (!ultimoError) ultimoError = new Error(`Sin respuesta en ${segundos}s`);
      fallar();
    }, Math.max(limite - ahora(), 0));

    const siguienteCandidato = () => {
      const t = ahora();
      const libres = candidatosDisponibles().filter(
        ({ llave, modelo }) =>
          !intentados.has(clavePar(llave, modelo)) &&
          !enVuelo.has(clavePar(llave, modelo)) &&
          bloqueadoHasta(llave, modelo) <= t
      );
      const modelosEnVuelo = new Set([...enVuelo.keys()].map((k) => k.split('|')[1]));
      return libres.find(({ modelo }) => !modelosEnVuelo.has(modelo)) || libres[0];
    };

    const programarRespaldo = () => {
      clearTimeout(temporizadorRespaldo);
      if (terminado || enVuelo.size >= maxParalelas) return;
      temporizadorRespaldo = setTimeout(() => {
        if (terminado || enVuelo.size >= maxParalelas) return;
        if (limite - ahora() < 8000) return;
        for (const clave of enVuelo.keys()) marcarLento(clave.split('|')[1]);
        if (lanzar()) console.log(`[Gemini] ${etiqueta}: respuesta lenta, se lanzó una solicitud de respaldo.`);
      }, respaldoMs);
    };

    const reabastecer = () => {
      if (terminado) return;
      if (enVuelo.size < maxParalelas && lanzar()) return;
      if (enVuelo.size > 0) {
        programarRespaldo();
        return;
      }

      if (ronda >= RONDAS_MAXIMAS) return fallar();
      const espera = proximoDesbloqueo() - ahora();
      const restante = limite - ahora();
      if (!Number.isFinite(espera) || espera > ESPERA_MAXIMA_MS || espera + 3000 > restante) return fallar();
      ronda++;
      intentados = new Set();
      temporizadorEspera = setTimeout(reabastecer, Math.max(espera, 0) + 300 + Math.floor(Math.random() * 700));
    };

    const lanzar = (forzado = null, sinThinking = false) => {
      if (terminado || enVuelo.size >= maxParalelas) return false;
      const restante = limite - ahora();
      if (restante < 3000) {
        if (!enVuelo.size) fallar();
        return false;
      }
      const cand = forzado || siguienteCandidato();
      if (!cand) return false;

      const { llave, modelo } = cand;
      const clave = clavePar(llave, modelo);
      intentados.add(clave);
      const controlador = new AbortController();
      enVuelo.set(clave, controlador);
      const usarThinking = sinThinking || modelosSinThinking.has(modelo) ? null : thinking;
      const inicio = ahora();
      registrarUso(llave, modelo);

      llamar({
        llave,
        modelo,
        contents,
        config,
        thinking: usarThinking,
        timeoutMs: Math.min(timeoutMs, restante),
        controlador,
      })
        .then((respuesta) => {
          if (terminado) return;
          enVuelo.delete(clave);
          const texto = respuesta && respuesta.text;
          if (!texto) {
            ultimoError = new Error('Respuesta vacía');
            console.warn(`[Gemini] ${etiqueta}: ${modelo} (llave #${llave + 1}) devolvió una respuesta vacía.`);
            return reabastecer();
          }
          let valor;
          try {
            valor = procesar(texto);
          } catch (errProcesar) {
            ultimoError = errProcesar;
            console.warn(`[Gemini] ${etiqueta}: ${modelo} (llave #${llave + 1}) devolvió un formato inválido.`);
            return reabastecer();
          }
          const duracion = ahora() - inicio;
          if (duracion > LENTO_MS) marcarLento(modelo);
          else modelosLentos.delete(modelo);
          console.log(`[Gemini] ${etiqueta}: ${modelo} (llave #${llave + 1}) respondió en ${duracion} ms`);
          exito(valor);
        })
        .catch((err) => {
          if (terminado) return;
          enVuelo.delete(clave);
          ultimoError = err;
          const info = clasificarError(err);
          console.warn(
            `[Gemini] ${etiqueta}: falló ${modelo} (llave #${llave + 1}) tras ${Math.round((ahora() - inicio) / 1000)}s -> ${info.tipo}${info.esperaMs ? ` (bloqueado ${Math.round(info.esperaMs / 1000)}s)` : ''}${info.tipo === 'desconocido' || info.tipo === 'peticion' ? `: ${String(err && err.message).slice(0, 160)}` : ''}`
          );
          if (info.tipo === 'peticion' && usarThinking) {
            modelosSinThinking.add(modelo);
            intentados.delete(clave);
            if (lanzar(cand, true)) return;
          }
          if (info.tipo === 'tiempo') marcarLento(modelo);
          aplicarBloqueo(llave, modelo, info);
          reabastecer();
        });

      programarRespaldo();
      return true;
    };

    reabastecer();
  });

const generarJSON = (
  prompt,
  schema,
  { thinking = ThinkingLevel.LOW, etiqueta = 'JSON', presupuestoMs, timeoutMs, respaldoMs, validar } = {}
) =>
  generarContenido({
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      ...(schema ? { responseSchema: schema } : {}),
    },
    thinking,
    procesar: (texto) => {
      const data = JSON.parse(texto);
      if (validar && !validar(data)) throw new Error('JSON incompleto');
      return data;
    },
    etiqueta,
    presupuestoMs,
    timeoutMs,
    respaldoMs,
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