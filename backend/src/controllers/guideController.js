const db = require('../config/db');
const { Type } = require('@google/genai');
const {
  generarJSON,
  IANoDisponibleError,
  MENSAJE_IA_SATURADA,
  ThinkingLevel,
} = require('../services/geminiService');

const SECCIONES_POR_SEMANA = 3;
const TEMAS_POR_SECCION = 3;
const CONCEPTOS_POR_TEMA = 3;
const BLOQUES_DESARROLLO = 3;
const PREGUNTAS_POR_EXAMEN = 10;
const MINUTOS_POR_EXAMEN = 15;
const INCISOS = ['A', 'B', 'C', 'D'];

const entero = (valor, defecto) => {
  const n = parseInt(valor, 10);
  return Number.isFinite(n) && n > 0 ? n : defecto;
};

const CONCURRENCIA = entero(process.env.GEMINI_CONCURRENCIA, 12);
const INTENTOS_POR_PARTE = entero(process.env.GEMINI_INTENTOS_PARTE, 2);
const MINIMO_PREGUNTAS_IA = 6;
const PRESUPUESTO_TOTAL_MS = entero(process.env.GEMINI_PRESUPUESTO_TOTAL_MS, 270000);
const LIMITE_ESTRUCTURA_MS = entero(process.env.GEMINI_LIMITE_ESTRUCTURA_MS, 110000);
const RESERVA_RESCATE_MS = 55000;
const RESERVA_EXAMEN_MS = 25000;
const RESERVA_GUARDADO_MS = 8000;

const restanteHasta = (fin) => Math.max(fin - Date.now(), 0);

const nivelThinking = (valor, defecto) => {
  const v = String(valor || '').trim().toUpperCase();
  if (!v) return defecto;
  if (['NONE', 'NO', 'OFF', '0'].includes(v)) return null;
  return ThinkingLevel[v] || defecto;
};

const THINKING_ESTRUCTURA = nivelThinking(process.env.GEMINI_THINKING_ESTRUCTURA, ThinkingLevel.MINIMAL);
const THINKING_CONTENIDO = nivelThinking(process.env.GEMINI_THINKING_CONTENIDO, ThinkingLevel.MINIMAL);
const THINKING_EXAMEN = nivelThinking(process.env.GEMINI_THINKING_EXAMEN, ThinkingLevel.MINIMAL);

const generandoPorUsuario = new Set();

const obtenerPlan = (semanas) => {
  const n = Math.min(Math.max(parseInt(semanas, 10) || 1, 1), 4);
  return {
    semanas: n,
    secciones: n * SECCIONES_POR_SEMANA,
    temas: TEMAS_POR_SECCION,
    conceptos: CONCEPTOS_POR_TEMA,
  };
};

const mapConcurrente = async (items, limite, fn) => {
  const resultados = new Array(items.length);
  let siguiente = 0;
  const trabajador = async () => {
    while (siguiente < items.length) {
      const i = siguiente++;
      resultados[i] = await fn(items[i], i);
    }
  };
  await Promise.all(Array.from({ length: Math.min(limite, items.length) }, trabajador));
  return resultados;
};

const estructuraSchema = {
  type: Type.OBJECT,
  properties: {
    hilo_conductor: {
      type: Type.OBJECT,
      properties: {
        pregunta_central: { type: Type.STRING },
        meta: { type: Type.STRING },
        datos_base: { type: Type.STRING },
      },
      required: ['pregunta_central', 'meta', 'datos_base'],
    },
    secciones: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          titulo_seccion: { type: Type.STRING },
          objetivo: { type: Type.STRING },
          conexion: { type: Type.STRING },
          aporte: { type: Type.STRING },
          temas: { type: Type.ARRAY, items: { type: Type.STRING } },
        },
        required: ['titulo_seccion', 'objetivo', 'conexion', 'aporte', 'temas'],
      },
    },
  },
  required: ['hilo_conductor', 'secciones'],
};

const temasSchema = {
  type: Type.OBJECT,
  properties: {
    temas: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          titulo: { type: Type.STRING },
          conexion_previa: { type: Type.STRING },
          introduccion: { type: Type.STRING },
          desarrollo: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                subtitulo: { type: Type.STRING },
                texto: { type: Type.STRING },
              },
              required: ['subtitulo', 'texto'],
            },
          },
          conceptos: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                titulo: { type: Type.STRING },
                explicacion: { type: Type.STRING },
              },
              required: ['titulo', 'explicacion'],
            },
          },
          ejemplo: { type: Type.STRING },
          consejo: { type: Type.STRING },
          resumen: { type: Type.STRING },
          puente_siguiente: { type: Type.STRING },
        },
        required: [
          'titulo',
          'conexion_previa',
          'introduccion',
          'desarrollo',
          'conceptos',
          'ejemplo',
          'consejo',
          'resumen',
          'puente_siguiente',
        ],
      },
    },
  },
  required: ['temas'],
};

const examenSchema = {
  type: Type.OBJECT,
  properties: {
    preguntas: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          pregunta: { type: Type.STRING },
          opciones: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                inciso: { type: Type.STRING, enum: INCISOS },
                texto: { type: Type.STRING },
              },
              required: ['inciso', 'texto'],
            },
          },
          respuesta_correcta: { type: Type.STRING, enum: INCISOS },
          justificacion: { type: Type.STRING },
        },
        required: ['pregunta', 'opciones', 'respuesta_correcta', 'justificacion'],
      },
    },
  },
  required: ['preguntas'],
};

const seccionSchema = {
  type: Type.OBJECT,
  properties: {
    temas: temasSchema.properties.temas,
    preguntas: examenSchema.properties.preguntas,
  },
  required: ['temas', 'preguntas'],
  propertyOrdering: ['temas', 'preguntas'],
};

const limpiarTexto = (valor) => (typeof valor === 'string' ? valor.trim() : '');

const normalizarClave = (texto) =>
  limpiarTexto(texto)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const mezclar = (lista) => {
  const copia = [...lista];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
};

const REFERENCIA_A_OPCIONES = /anteriores|ambas|ninguna de|todas las|inciso|opci[oó]n\s+[abcd]\b|\b[ABCD]\)\s*y\s*[ABCD]\)/i;

const mezclarOpciones = (pregunta) => {
  if (pregunta.opciones.some((op) => REFERENCIA_A_OPCIONES.test(op.texto))) return pregunta;
  const textoCorrecto = pregunta.opciones.find((op) => op.inciso === pregunta.respuesta_correcta).texto;
  const opciones = mezclar(pregunta.opciones.map((op) => op.texto)).map((texto, i) => ({ inciso: INCISOS[i], texto }));
  const correcta = opciones.find((op) => op.texto === textoCorrecto).inciso;
  return { ...pregunta, opciones, respuesta_correcta: correcta };
};

const normalizarPregunta = (preg) => {
  const enunciado = limpiarTexto(preg && preg.pregunta);
  const opcionesRaw = Array.isArray(preg && preg.opciones) ? preg.opciones : [];
  const opciones = opcionesRaw
    .map((op) => limpiarTexto(op && (op.texto || op.opcion)))
    .filter(Boolean)
    .slice(0, INCISOS.length)
    .map((texto, i) => ({ inciso: INCISOS[i], texto }));

  if (!enunciado || opciones.length !== INCISOS.length) return null;
  if (new Set(opciones.map((op) => normalizarClave(op.texto))).size !== INCISOS.length) return null;

  let correcta = limpiarTexto(preg.respuesta_correcta).toUpperCase();
  if (!INCISOS.includes(correcta)) {
    const original = opcionesRaw.findIndex(
      (op) => limpiarTexto(op && op.texto).toLowerCase() === limpiarTexto(preg.respuesta_correcta).toLowerCase()
    );
    correcta = original >= 0 && original < INCISOS.length ? INCISOS[original] : '';
  } else {
    const idx = opcionesRaw.findIndex((op) => limpiarTexto(op && op.inciso).toUpperCase() === correcta);
    if (idx >= 0 && idx < INCISOS.length) correcta = INCISOS[idx];
  }

  if (!correcta) return null;
  return mezclarOpciones({ pregunta: enunciado, opciones, respuesta_correcta: correcta });
};

const normalizarTema = (tema, plan, contexto = {}) => {
  const titulo = limpiarTexto(tema && tema.titulo);
  const introduccion = limpiarTexto(tema && tema.introduccion);
  if (!titulo || !introduccion) return null;

  const conceptos = (Array.isArray(tema.conceptos) ? tema.conceptos : [])
    .map((c) => ({ titulo: limpiarTexto(c && c.titulo), explicacion: limpiarTexto(c && c.explicacion) }))
    .filter((c) => c.titulo && c.explicacion)
    .slice(0, plan.conceptos);

  const desarrollo = (Array.isArray(tema.desarrollo) ? tema.desarrollo : [])
    .map((b) => ({ subtitulo: limpiarTexto(b && b.subtitulo), texto: limpiarTexto(b && b.texto) }))
    .filter((b) => b.texto)
    .slice(0, BLOQUES_DESARROLLO);

  return {
    titulo,
    contenido: {
      version: 4,
      conexion_seccion: contexto.esPrimero ? contexto.conexionSeccion || '' : '',
      conexion_previa: limpiarTexto(tema.conexion_previa),
      introduccion,
      desarrollo,
      conceptos,
      ejemplo: limpiarTexto(tema.ejemplo),
      consejo: limpiarTexto(tema.consejo),
      resumen: limpiarTexto(tema.resumen),
      puente_siguiente: limpiarTexto(tema.puente_siguiente),
    },
  };
};

const temaUtil = (t) => t && t.contenido.conceptos.length > 0 && t.contenido.desarrollo.length > 0;

const normalizarHilo = (hilo) => ({
  pregunta_central: limpiarTexto(hilo && hilo.pregunta_central),
  meta: limpiarTexto(hilo && hilo.meta),
  datos_base: limpiarTexto(hilo && hilo.datos_base),
});

const describirHilo = (hilo) =>
  hilo && hilo.pregunta_central
    ? `Pregunta central que responde el curso: ${hilo.pregunta_central}
Lo que el estudiante sabrá hacer al final: ${hilo.meta}
Cifras de ejemplo hipotéticas para ilustrar (reutilízalas con estos mismos valores): ${hilo.datos_base}`
    : 'Usa cifras de referencia coherentes y constantes en todos los ejemplos de la sección.';

const normalizarSecciones = (data, plan) =>
  (Array.isArray(data && data.secciones) ? data.secciones : [])
    .map((s) => ({
      titulo: limpiarTexto(s && s.titulo_seccion),
      objetivo: limpiarTexto(s && s.objetivo),
      conexion: limpiarTexto(s && s.conexion),
      aporte: limpiarTexto(s && s.aporte),
      temas: (Array.isArray(s && s.temas) ? s.temas : []).map(limpiarTexto).filter(Boolean).slice(0, plan.temas),
    }))
    .filter((s) => s.titulo && s.temas.length === plan.temas)
    .slice(0, plan.secciones);

const generarEstructura = async (tema, nivel, plan, finEstructura) => {
  const prompt = `Eres un experto educador en finanzas personales y diseñador instruccional.
Diseña el temario de un curso sobre "${tema}" para nivel "${nivel}", con duración de ${plan.semanas} semana(s) (${SECCIONES_POR_SEMANA} secciones por semana).

El curso debe sentirse como UN solo recorrido de aprendizaje, no como temas sueltos. No uses personajes ni nombres de personas.

Reglas OBLIGATORIAS:
1. "hilo_conductor": "pregunta_central" es la gran pregunta práctica que el curso responde; "meta" es lo que el estudiante sabrá hacer al final; "datos_base" son cifras de referencia en pesos mexicanos (por ejemplo un ingreso mensual, gastos principales, deuda o ahorro, según aplique) que se reutilizarán como ejemplo hipotético en todo el curso.
2. Exactamente ${plan.secciones} secciones progresivas: cada sección se apoya en lo aprendido en la anterior y prepara la siguiente. Nada se repite.
3. "conexion": una oración que explique cómo esta sección retoma lo aprendido en la sección anterior (en la primera sección, por qué es el punto de partida para responder la pregunta central).
4. "aporte": una oración sobre qué parte de la pregunta central resuelve esta sección.
5. Cada sección tiene exactamente ${plan.temas} temas con títulos cortos y específicos (máximo 8 palabras), ordenados para que cada tema necesite el anterior.
6. "objetivo" es una sola oración que dice qué podrá hacer el estudiante al terminar la sección.
7. Todo en español neutro.`;

  let mejor = null;
  let ultimoError = null;

  for (let intento = 1; intento <= INTENTOS_POR_PARTE; intento++) {
    if (restanteHasta(finEstructura) < 10000) break;
    try {
      const data = await generarJSON(prompt, estructuraSchema, {
        etiqueta: 'estructura',
        thinking: intento === 1 ? THINKING_ESTRUCTURA : null,
        presupuestoMs: restanteHasta(finEstructura),
        timeoutMs: 80000,
        respaldoMs: 35000,
      });
      const secciones = normalizarSecciones(data, plan);
      const hilo = normalizarHilo(data && data.hilo_conductor);
      if (secciones.length === plan.secciones) return { hilo, secciones };

      const completas = Math.floor(secciones.length / SECCIONES_POR_SEMANA) * SECCIONES_POR_SEMANA;
      if (completas && (!mejor || completas > mejor.secciones.length)) {
        mejor = { hilo, secciones: secciones.slice(0, completas) };
      }
      console.warn(`Estructura incompleta (intento ${intento}): ${secciones.length}/${plan.secciones} secciones válidas`);
    } catch (err) {
      ultimoError = err;
      console.warn(`Error generando la estructura (intento ${intento}): ${err.causa ? err.causa.message : err.message}`);
    }
  }

  if (mejor) return mejor;
  throw new IANoDisponibleError(MENSAJE_IA_SATURADA, ultimoError);
};

const contextoSeccion = (tema, nivel, plan, seccion, indice, todas, hilo) => {
  const temario = todas
    .map((s, i) => `${i + 1}. ${s.titulo}: ${s.temas.join(' / ')}${s.aporte ? ` (aporta: ${s.aporte})` : ''}`)
    .join('\n');
  const anterior = indice > 0 ? todas[indice - 1] : null;
  const siguiente = indice < todas.length - 1 ? todas[indice + 1] : null;

  return `Eres un experto educador en finanzas personales y diseñador instruccional.
Curso: "${tema}" | Nivel: "${nivel}" | Duración: ${plan.semanas} semana(s).

HILO CONDUCTOR DEL CURSO:
${describirHilo(hilo)}

Temario completo del curso (contexto; no desarrolles otras secciones):
${temario}

${anterior ? `Sección anterior (${indice}): "${anterior.titulo}", con los temas: ${anterior.temas.join(', ')}. El estudiante YA domina eso.` : 'Esta es la PRIMERA sección: parte desde cero y plantea la pregunta central del curso.'}
${siguiente ? `Sección siguiente (${indice + 2}): "${siguiente.titulo}". Deja preparado el terreno para ella.` : 'Esta es la ÚLTIMA sección: cierra el recorrido respondiendo la pregunta central con todo lo aprendido.'}

Sección actual ${indice + 1}: "${seccion.titulo}".
Objetivo de la sección: ${seccion.objetivo}
${seccion.conexion ? `Cómo se conecta con lo anterior: ${seccion.conexion}` : ''}
${seccion.aporte ? `Qué parte de la pregunta central resuelve: ${seccion.aporte}` : ''}

Temas de la sección, en este orden:
${seccion.temas.map((t, i) => `${i + 1}. ${t}`).join('\n')}`;
};

const reglasTemas = (plan) => `COHERENCIA (lo más importante):
- Los temas de la sección forman una secuencia: cada uno usa lo que se explicó en el tema anterior y lo menciona de forma natural.
- Los conceptos de un tema se relacionan entre sí: el segundo y el tercero se apoyan explícitamente en el primero.
- Todos los ejemplos usan las MISMAS cifras de referencia y continúan el cálculo del tema anterior; si una cifra cambia, explica por qué.
- No uses personajes ni nombres propios: habla en segunda persona ("si tu ingreso es...") o de forma impersonal.
- Las cifras son HIPOTÉTICAS: preséntalas siempre como ejemplo ("por ejemplo, si ganaras $X al mes...", "imagina que...", "supongamos que..."), nunca como datos reales, promedios oficiales ni como la situación del estudiante.
- Escribe SIEMPRE las cifras con números y signo, nunca con letra: "$18,000 MXN", "$2,500", "15%" (no "dieciocho mil pesos" ni "quince por ciento").

Reglas OBLIGATORIAS para cada tema:
- "conexion_previa": una oración que conecte el tema con lo que el estudiante acaba de ver (en el tema 1, con la sección anterior o, si es la primera sección, con la pregunta central del curso).
- "introduccion": un párrafo de 2 a 3 oraciones: de qué trata, por qué importa y cómo ayuda a responder la pregunta central.
- "desarrollo": exactamente ${BLOQUES_DESARROLLO} bloques que explican el tema como lo haría un buen maestro, con contexto y sin relleno. Cada bloque tiene un "subtitulo" corto (máximo 5 palabras) y un "texto" de 2 a 3 oraciones:
   1) Qué es: define el tema de forma sencilla (por ejemplo: "Los impuestos son aportaciones obligatorias que...").
   2) Cómo se compone o qué tipos hay: explica sus partes o variantes (por ejemplo: "Dentro de ellos están...", "Se divide en...").
   3) Cómo funciona en la vida real: cuándo aparece, cómo te afecta y qué decisión cambia (puede usar las cifras de referencia).
   Los bloques van en ese orden y cada uno se apoya en el anterior. No repitas la introducción ni los conceptos al pie de la letra.
- "conceptos": exactamente ${plan.conceptos} conceptos clave, cada uno con "titulo" corto y "explicacion" de 1 a 2 oraciones, encadenados entre sí.
- "ejemplo": de 2 a 4 oraciones que empiecen como caso hipotético ("Supongamos que...", "Imagina que...") con las cifras de referencia en pesos mexicanos (MXN), aplicando los conceptos del tema.
- "consejo": una recomendación accionable de una oración.
- "resumen": una oración que sintetice lo más importante y cómo se suma a lo anterior.
- "puente_siguiente": una oración sobre qué queda abierto y que resuelve el siguiente tema (en el último tema, lo que viene en la siguiente sección o el examen).
- Lenguaje claro y directo. Texto plano, sin Markdown, sin asteriscos ni viñetas.`;

const asignarTemas = (recibidos, faltantes, seccion, plan, obtenidos) => {
  const libres = [...faltantes];
  recibidos.forEach((t, k) => {
    const clave = normalizarClave(t && t.titulo);
    let destino = libres.find((i) => normalizarClave(seccion.temas[i]) === clave);
    if (destino === undefined && recibidos.length === faltantes.length) destino = faltantes[k];
    if (destino === undefined || !libres.includes(destino)) return;
    const normal = normalizarTema({ ...t, titulo: seccion.temas[destino] }, plan, {
      esPrimero: destino === 0,
      conexionSeccion: seccion.conexion,
    });
    if (temaUtil(normal)) {
      obtenidos[destino] = normal;
      libres.splice(libres.indexOf(destino), 1);
    }
  });
  return libres;
};

const rescatarTema = async (base, plan, seccion, indice, i, obtenidos, finRescate) => {
  const previo = i > 0 ? obtenidos[i - 1] : null;
  const siguiente = i < seccion.temas.length - 1 ? seccion.temas[i + 1] : null;
  const prompt = `${base}

Desarrolla ÚNICAMENTE el tema ${i + 1}: "${seccion.temas[i]}" (devuelve un arreglo "temas" con exactamente 1 elemento y ese mismo título).
${previo ? `El tema anterior fue "${previo.titulo}". Lo que el estudiante acaba de aprender: ${previo.contenido.resumen} ${previo.contenido.puente_siguiente}` : ''}
${siguiente ? `El siguiente tema será "${siguiente}"; deja preparado el terreno para él.` : ''}

${reglasTemas(plan)}`;

  if (restanteHasta(finRescate) < 5000) return;
  try {
    const data = await generarJSON(prompt, temasSchema, {
      etiqueta: `rescate tema ${i + 1} sección ${indice + 1}`,
      thinking: null,
      presupuestoMs: restanteHasta(finRescate),
      timeoutMs: 45000,
    });
    const recibidos = Array.isArray(data && data.temas) ? data.temas.slice(0, 1) : [];
    asignarTemas(recibidos, [i], seccion, plan, obtenidos);
  } catch (err) {
    if (!(err instanceof IANoDisponibleError)) {
      console.warn(`Error en rescate del tema ${i + 1} de la sección ${indice + 1}: ${err.message}`);
    }
  }
};

const reglasExamen = (cantidad, totalTemas, fuente) => `Reglas OBLIGATORIAS del examen (${cantidad} preguntas de opción múltiple):
- Pregunta SOLO sobre conceptos, definiciones y cálculos que aparecen en ${fuente}. Si algo no está explicado ahí, no lo preguntes.
- Usa los mismos nombres de conceptos y las mismas cifras de los ejemplos; si haces un cálculo nuevo, que se resuelva con lo explicado y verifica la aritmética antes de responder.
- Reparte las preguntas entre los ${totalTemas} temas; al menos ${Math.min(4, cantidad)} son casos prácticos con las cifras de los ejemplos y al menos ${Math.min(2, cantidad)} combinan conceptos de temas distintos.
- "justificacion": una frase breve tomada o parafraseada del contenido que demuestra que la respuesta correcta es la correcta.
- Cada pregunta con exactamente 4 opciones distintas entre sí con incisos "A", "B", "C" y "D", en ese orden.
- "respuesta_correcta" es SOLO la letra del inciso correcto ("A", "B", "C" o "D").
- Solo una opción correcta por pregunta; los distractores son plausibles pero claramente incorrectos según el contenido.
- No uses opciones como "Todas las anteriores", "Ninguna de las anteriores" ni "A y B".
- Enunciados y opciones breves. Sin personajes ni nombres propios. Texto plano, sin Markdown.`;

const generarContenidoSeccion = async (base, plan, seccion, indice, fin) => {
  const obtenidos = new Array(plan.temas).fill(null);
  const finNormal = fin - RESERVA_RESCATE_MS;
  const finRescate = fin - RESERVA_EXAMEN_MS;
  let preguntasIA = [];

  for (let intento = 1; intento <= INTENTOS_POR_PARTE; intento++) {
    const faltantes = obtenidos.map((t, i) => (t ? -1 : i)).filter((i) => i >= 0);
    if (!faltantes.length) break;
    if (restanteHasta(finNormal) < 8000) break;

    const conExamen = faltantes.length === plan.temas;
    const prompt = `${base}

${conExamen ? 'PRIMERO, en "temas", desarrolla' : 'Desarrolla ÚNICAMENTE'} estos temas de la sección (exactamente ${faltantes.length}, con el mismo título y en este orden):
${faltantes.map((i) => `${i + 1}. ${seccion.temas[i]}`).join('\n')}

${reglasTemas(plan)}${conExamen ? `

DESPUÉS, en "preguntas", crea el examen de la sección basándote ÚNICAMENTE en lo que tú mismo escribiste en "temas".
${reglasExamen(PREGUNTAS_POR_EXAMEN, plan.temas, 'los temas que escribiste')}` : ''}`;

    try {
      const data = await generarJSON(prompt, conExamen ? seccionSchema : temasSchema, {
        etiqueta: `${conExamen ? 'sección' : 'temas sección'} ${indice + 1}`,
        thinking: THINKING_CONTENIDO,
        presupuestoMs: restanteHasta(finNormal),
        timeoutMs: 90000,
      });
      const recibidos = Array.isArray(data && data.temas) ? data.temas : [];
      const libres = asignarTemas(recibidos, faltantes, seccion, plan, obtenidos);
      if (conExamen && !libres.length && Array.isArray(data.preguntas)) preguntasIA = data.preguntas;
      if (libres.length) {
        console.warn(`Temas incompletos en sección ${indice + 1} (intento ${intento}): faltan ${libres.length}`);
      }
    } catch (err) {
      if (err instanceof IANoDisponibleError) break;
      console.warn(`Error generando la sección ${indice + 1} (intento ${intento}): ${err.message}`);
    }
  }

  for (let i = 0; i < obtenidos.length; i++) {
    if (!obtenidos[i]) await rescatarTema(base, plan, seccion, indice, i, obtenidos, finRescate);
  }

  return { temas: obtenidos.every(Boolean) ? obtenidos : null, preguntasIA };
};

const resumirContenido = (temas) =>
  temas
    .map((t, i) => {
      const c = t.contenido;
      const conceptos = c.conceptos.map((x) => `   - ${x.titulo}: ${x.explicacion}`).join('\n');
      return `Tema ${i + 1}: ${t.titulo}
  Idea principal: ${c.introduccion}
  Contenido:
${(c.desarrollo || []).map((b) => `   - ${b.subtitulo}: ${b.texto}`).join('\n')}
  Conceptos:
${conceptos}
  Ejemplo: ${c.ejemplo}
  Resumen: ${c.resumen}`;
    })
    .join('\n\n');

const recortar = (texto, max = 220) => {
  const t = limpiarTexto(texto);
  if (t.length <= max) return t;
  const corte = t.slice(0, max);
  const punto = corte.lastIndexOf('. ');
  return punto > max * 0.5 ? corte.slice(0, punto + 1) : `${corte.slice(0, corte.lastIndexOf(' '))}…`;
};

const preguntasDeRespaldo = (temas, vistas, faltan) => {
  const conceptos = [];
  const bloques = [];
  const resumenes = [];
  temas.forEach((t) => {
    t.contenido.conceptos.forEach((c) => conceptos.push({ tema: t.titulo, titulo: c.titulo, texto: recortar(c.explicacion) }));
    t.contenido.desarrollo.forEach((b) =>
      bloques.push({ tema: t.titulo, titulo: b.subtitulo || t.titulo, texto: recortar(b.texto) })
    );
    if (t.contenido.resumen) resumenes.push({ tema: t.titulo, titulo: t.titulo, texto: recortar(t.contenido.resumen) });
  });

  const todos = [...conceptos, ...bloques, ...resumenes];
  const crear = (item, enunciado, mismoTipo) => {
    const usados = new Set([normalizarClave(item.texto)]);
    const distractores = [];
    for (const otro of [...mezclar(mismoTipo), ...mezclar(todos)]) {
      const clave = normalizarClave(otro.texto);
      if (distractores.length >= 3) break;
      if (!clave || usados.has(clave)) continue;
      usados.add(clave);
      distractores.push(otro.texto);
    }
    if (distractores.length < 3) return null;
    const textos = mezclar([item.texto, ...distractores]);
    const opciones = textos.map((texto, i) => ({ inciso: INCISOS[i], texto }));
    return {
      pregunta: enunciado,
      opciones,
      respuesta_correcta: INCISOS[textos.indexOf(item.texto)],
    };
  };

  const candidatas = [
    ...mezclar(conceptos).map((c) => crear(c, `¿Qué describe correctamente el concepto «${c.titulo}» del tema «${c.tema}»?`, conceptos)),
    ...mezclar(resumenes).map((r) => crear(r, `¿Cuál es la idea más importante del tema «${r.tema}»?`, resumenes)),
    ...mezclar(bloques).map((b) => crear(b, `Dentro del tema «${b.tema}», ¿qué afirmación corresponde a «${b.titulo}»?`, bloques)),
  ].filter(Boolean);

  const resultado = [];
  for (const p of candidatas) {
    if (resultado.length >= faltan) break;
    const clave = normalizarClave(p.pregunta);
    if (vistas.has(clave)) continue;
    vistas.add(clave);
    resultado.push(p);
  }
  return resultado;
};

const agregarPreguntas = (lista, preguntas, vistas) => {
  (Array.isArray(lista) ? lista : [])
    .map(normalizarPregunta)
    .filter(Boolean)
    .forEach((p) => {
      const clave = normalizarClave(p.pregunta);
      if (preguntas.length < PREGUNTAS_POR_EXAMEN && !vistas.has(clave)) {
        vistas.add(clave);
        preguntas.push(p);
      }
    });
};

const generarExamenSeccion = async (base, seccion, indice, temas, fin, preguntasIA) => {
  const finExamen = fin - RESERVA_GUARDADO_MS;
  const preguntas = [];
  const vistas = new Set();
  agregarPreguntas(preguntasIA, preguntas, vistas);

  if (preguntas.length < MINIMO_PREGUNTAS_IA && restanteHasta(finExamen) >= 6000) {
    const faltan = PREGUNTAS_POR_EXAMEN - preguntas.length;
    const prompt = `${base}

CONTENIDO QUE EL ESTUDIANTE ACABA DE ESTUDIAR (el examen debe basarse ÚNICAMENTE en esto):
${resumirContenido(temas)}

Crea ${faltan} preguntas de opción múltiple para el examen de esta sección.
${preguntas.length ? `Ya existen estas preguntas, NO las repitas:\n${preguntas.map((p) => `- ${p.pregunta}`).join('\n')}` : ''}

${reglasExamen(faltan, temas.length, 'el contenido de arriba')}`;

    try {
      const data = await generarJSON(prompt, examenSchema, {
        etiqueta: `examen sección ${indice + 1}`,
        thinking: THINKING_EXAMEN,
        presupuestoMs: restanteHasta(finExamen),
        timeoutMs: 45000,
      });
      agregarPreguntas(data && data.preguntas, preguntas, vistas);
    } catch (err) {
      if (!(err instanceof IANoDisponibleError)) {
        console.warn(`Error generando el examen de la sección ${indice + 1}: ${err.message}`);
      }
    }
  }

  if (preguntas.length < PREGUNTAS_POR_EXAMEN) {
    const extra = preguntasDeRespaldo(temas, vistas, PREGUNTAS_POR_EXAMEN - preguntas.length);
    if (extra.length) console.warn(`Examen de la sección ${indice + 1} completado con ${extra.length} pregunta(s) del contenido.`);
    preguntas.push(...extra);
  }
  return preguntas;
};

const generarSeccion = async (tema, nivel, plan, seccion, indice, todas, hilo, fin) => {
  try {
    const base = contextoSeccion(tema, nivel, plan, seccion, indice, todas, hilo);
    const { temas, preguntasIA } = await generarContenidoSeccion(base, plan, seccion, indice, fin);
    if (!temas) {
      console.warn(`La sección ${indice + 1} no se pudo completar a tiempo.`);
      return null;
    }
    const preguntas = await generarExamenSeccion(base, seccion, indice, temas, fin, preguntasIA);
    if (!preguntas.length) return null;
    return { ...seccion, temas, preguntas };
  } catch (err) {
    console.warn(`Falló la sección ${indice + 1}: ${err.message}`);
    return null;
  }
};

const seccionesUtilizables = (resultado) => {
  const prefijo = [];
  for (const s of resultado) {
    if (!s) break;
    prefijo.push(s);
  }
  const completas = Math.floor(prefijo.length / SECCIONES_POR_SEMANA) * SECCIONES_POR_SEMANA;
  return prefijo.slice(0, completas);
};

const cerrarCurso = (secciones) => {
  const ultima = secciones[secciones.length - 1];
  const ultimoTema = ultima.temas[ultima.temas.length - 1];
  ultimoTema.contenido.puente_siguiente =
    'Con esto completas el recorrido de esta guía. Pon a prueba todo lo aprendido en el examen de la sección.';
};

const guardarCurso = async (id_usuario, idTema, secciones) => {
  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const guideResult = await client.query(
      `INSERT INTO guia_estudio (id_usuario, id_tema, fecha_creacion)
       VALUES ($1, $2, NOW())
       RETURNING id_guia`,
      [id_usuario, idTema]
    );
    const idGuia = guideResult.rows[0].id_guia;

    const secResult = await client.query(
      `INSERT INTO seccion (id_guia, titulo, orden_seccion)
       SELECT $1, t.titulo, t.orden
       FROM unnest($2::text[], $3::int[]) AS t(titulo, orden)
       RETURNING id_seccion, orden_seccion`,
      [idGuia, secciones.map((s) => s.titulo.slice(0, 150)), secciones.map((_, i) => i + 1)]
    );
    const idPorOrden = new Map(secResult.rows.map((r) => [r.orden_seccion, r.id_seccion]));
    const idsSeccion = secciones.map((_, i) => idPorOrden.get(i + 1));

    await client.query(
      `INSERT INTO avance_seccion (id_seccion, id_usuario, completado)
       SELECT unnest($1::int[]), $2, FALSE
       ON CONFLICT (id_usuario, id_seccion) DO NOTHING`,
      [idsSeccion, id_usuario]
    );

    const cont = { ids: [], titulos: [], contenidos: [], ordenes: [] };
    secciones.forEach((sec, i) => {
      sec.temas.forEach((t, j) => {
        cont.ids.push(idsSeccion[i]);
        cont.titulos.push(t.titulo.slice(0, 150));
        cont.contenidos.push(JSON.stringify(t.contenido));
        cont.ordenes.push(j + 1);
      });
    });
    await client.query(
      `INSERT INTO contenido_seccion (id_seccion, titulo, contenido, orden_contenido)
       SELECT * FROM unnest($1::int[], $2::text[], $3::text[], $4::int[])`,
      [cont.ids, cont.titulos, cont.contenidos, cont.ordenes]
    );

    const examResult = await client.query(
      `INSERT INTO examen (id_seccion, tiempo_duracion_minutos)
       SELECT unnest($1::int[]), $2
       RETURNING id_examen, id_seccion`,
      [idsSeccion, MINUTOS_POR_EXAMEN]
    );
    const examenPorSeccion = new Map(examResult.rows.map((r) => [r.id_seccion, r.id_examen]));

    const preg = { ids: [], textos: [], opciones: [], correctas: [] };
    secciones.forEach((sec, i) => {
      const idExamen = examenPorSeccion.get(idsSeccion[i]);
      sec.preguntas.forEach((p) => {
        preg.ids.push(idExamen);
        preg.textos.push(p.pregunta);
        preg.opciones.push(JSON.stringify(p.opciones));
        preg.correctas.push(p.respuesta_correcta);
      });
    });
    await client.query(
      `INSERT INTO pregunta (id_examen, pregunta, opciones, respuesta_correcta)
       SELECT t.id_examen, t.pregunta, t.opciones::jsonb, t.correcta
       FROM unnest($1::int[], $2::text[], $3::text[], $4::text[]) AS t(id_examen, pregunta, opciones, correcta)`,
      [preg.ids, preg.textos, preg.opciones, preg.correctas]
    );

    await client.query('COMMIT');
    return idGuia;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

// 1. GENERAR CURSO/GUÍA CON GOOGLE GEMINI Y GUARDAR EN POSTGRESQL
exports.generateCourse = async (req, res) => {
  const { tema, nivel, duracion_semanas } = req.body;
  const id_usuario = req.user.id_usuario;

  if (!tema) {
    return res.status(400).json({ message: 'El tema es requerido para generar la guía.' });
  }

  if (generandoPorUsuario.has(id_usuario)) {
    return res.status(409).json({
      message: 'Ya estamos generando una guía para ti. Espera a que termine antes de crear otra.',
    });
  }
  generandoPorUsuario.add(id_usuario);

  try {
    // A. Buscar o crear el id_tema según el nombre en la BD
    const temaQuery = await db.query(
      'SELECT id_tema FROM tema WHERE LOWER(nombre_tema) = LOWER($1) LIMIT 1',
      [tema]
    );

    let idTema;
    if (temaQuery.rows.length > 0) {
      idTema = temaQuery.rows[0].id_tema;
    } else {
      const newTema = await db.query(
        'INSERT INTO tema (nombre_tema, descripcion) VALUES ($1, $2) RETURNING id_tema',
        [tema, `Guía de estudio generada sobre ${tema}`]
      );
      idTema = newTema.rows[0].id_tema;
    }

    const nivelCurso = nivel || 'Intermedio';
    const plan = obtenerPlan(duracion_semanas);

    const inicio = Date.now();
    const fin = inicio + PRESUPUESTO_TOTAL_MS;
    const { hilo, secciones: estructura } = await generarEstructura(
      tema,
      nivelCurso,
      plan,
      Math.min(inicio + LIMITE_ESTRUCTURA_MS, fin)
    );

    const resultado = await mapConcurrente(estructura, CONCURRENCIA, (sec, i) =>
      generarSeccion(tema, nivelCurso, plan, sec, i, estructura, hilo, fin)
    );

    const secciones = seccionesUtilizables(resultado);
    if (!secciones.length) throw new IANoDisponibleError();

    const incompleta = secciones.length < plan.secciones;
    if (incompleta) cerrarCurso(secciones);

    const idGuia = await guardarCurso(id_usuario, idTema, secciones);
    console.log(
      `Guía ${idGuia} generada en ${Date.now() - inicio} ms (${secciones.length}/${plan.secciones} secciones)`
    );

    const semanasGeneradas = secciones.length / SECCIONES_POR_SEMANA;

    res.status(201).json({
      message: incompleta
        ? `Tu guía quedó lista con ${semanasGeneradas} de ${plan.semanas} semanas porque la IA estaba muy solicitada.`
        : 'Guía de estudio generada e insertada correctamente',
      id_guia: idGuia,
      incompleta,
      curso: {
        semanas: semanasGeneradas,
        semanas_solicitadas: plan.semanas,
        total_secciones: secciones.length,
        temas_por_seccion: plan.temas,
        preguntas_por_examen: PREGUNTAS_POR_EXAMEN,
        secciones: secciones.map((s, i) => ({
          orden_seccion: i + 1,
          titulo_seccion: s.titulo,
          objetivo: s.objetivo,
          temas: s.temas.map((t) => t.titulo),
          total_preguntas: s.preguntas.length,
        })),
      },
    });
  } catch (error) {
    console.error('Error al generar el curso con Gemini:', error);
    if (error instanceof IANoDisponibleError) {
      return res.status(503).json({ message: MENSAJE_IA_SATURADA });
    }
    res.status(500).json({ message: 'No se pudo generar tu guía en este momento. Inténtalo de nuevo en unos minutos.' });
  } finally {
    generandoPorUsuario.delete(id_usuario);
  }
};

// 2. OBTENER TEMAS DE LA BASE DE DATOS
exports.getTopics = async (req, res) => {
  try {
    const result = await db.query(
      'SELECT id_tema, nombre_tema, descripcion FROM tema ORDER BY id_tema ASC'
    );
    res.json({ temas: result.rows });
  } catch (error) {
    console.error('Error al obtener temas:', error);
    res.status(500).json({ message: 'Error al obtener temas de la BD' });
  }
};

// 3. OBTENER CURSOS DEL USUARIO
exports.getUserGuides = async (req, res) => {
  try {
    const userId = req.user.id_usuario;

    const result = await db.query(
      `SELECT 
        g.id_guia, 
        g.fecha_creacion,
        t.nombre_tema,
        t.descripcion AS descripcion_tema,
        COALESCE((SELECT COUNT(*) FROM seccion s WHERE s.id_guia = g.id_guia), 0) AS total_secciones,
        COALESCE((
          SELECT COUNT(*) 
          FROM avance_seccion a 
          JOIN seccion s ON a.id_seccion = s.id_seccion 
          WHERE s.id_guia = g.id_guia AND a.id_usuario = $1 AND a.completado = TRUE
        ), 0) AS secciones_completadas,
        COALESCE((
          SELECT COUNT(*)
          FROM seccion s
          JOIN examen e ON e.id_seccion = s.id_seccion
          WHERE s.id_guia = g.id_guia
            AND NOT EXISTS (
              SELECT 1 FROM intento_examen i
              WHERE i.id_examen = e.id_examen AND i.id_usuario = $1)
        ), 0) AS examenes_pendientes,
        COALESCE((
          SELECT COUNT(*)
          FROM seccion s
          JOIN examen e ON e.id_seccion = s.id_seccion
          WHERE s.id_guia = g.id_guia
        ), 0) AS total_examenes,
        COALESCE((
          SELECT COUNT(*)
          FROM seccion s
          JOIN examen e ON e.id_seccion = s.id_seccion
          WHERE s.id_guia = g.id_guia
            AND EXISTS (
              SELECT 1 FROM intento_examen i
              WHERE i.id_examen = e.id_examen AND i.id_usuario = $1)
        ), 0) AS examenes_presentados
       FROM guia_estudio g
       INNER JOIN tema t ON g.id_tema = t.id_tema
       WHERE g.id_usuario = $1
       ORDER BY g.fecha_creacion DESC`,
      [userId]
    );

    res.json({ guias: result.rows });
  } catch (error) {
    console.error('Error en getUserGuides:', error);
    res.status(500).json({ message: 'Error al consultar guías en la BD' });
  }
};

// 4. OBTENER DETALLE COMPLETO DE UNA GUÍA DE ESTUDIO
exports.getGuideDetails = async (req, res) => {
  const { id_guia } = req.params;
  const id_usuario = req.user.id_usuario;

  try {
    // A. Consultar la guía y su tema
    const guideQuery = await db.query(
      `SELECT g.id_guia, t.nombre_tema, t.descripcion
       FROM guia_estudio g
       JOIN tema t ON g.id_tema = t.id_tema
       WHERE g.id_guia = $1 AND g.id_usuario = $2`,
      [id_guia, id_usuario]
    );

    if (guideQuery.rows.length === 0) {
      return res.status(404).json({ message: 'Guía no encontrada' });
    }

    const guia = guideQuery.rows[0];

    // B. Consultar secciones de la guía
    const sectionsQuery = await db.query(
      `SELECT s.id_seccion, s.titulo, s.orden_seccion,
              COALESCE(a.completado, FALSE) AS completado
       FROM seccion s
       LEFT JOIN avance_seccion a ON s.id_seccion = a.id_seccion AND a.id_usuario = $2
       WHERE s.id_guia = $1
       ORDER BY s.orden_seccion ASC`,
      [id_guia, id_usuario]
    );

    const secciones = sectionsQuery.rows;

    // C. Consultar contenidos y exámenes para cada sección
    const idsSeccion = secciones.map((sec) => sec.id_seccion);

    const [contentQuery, examQuery, questionsQuery, attemptsQuery] = await Promise.all([
      db.query(
        `SELECT id_contenido, id_seccion, titulo, contenido, orden_contenido
         FROM contenido_seccion
         WHERE id_seccion = ANY($1::int[])
         ORDER BY id_seccion, orden_contenido ASC`,
        [idsSeccion]
      ),
      db.query(
        `SELECT DISTINCT ON (id_seccion) id_examen, id_seccion, tiempo_duracion_minutos
         FROM examen
         WHERE id_seccion = ANY($1::int[])
         ORDER BY id_seccion, id_examen ASC`,
        [idsSeccion]
      ),
      db.query(
        `SELECT p.id_pregunta, p.id_examen, p.pregunta, p.opciones, p.respuesta_correcta
         FROM pregunta p
         JOIN examen e ON e.id_examen = p.id_examen
         WHERE e.id_seccion = ANY($1::int[])
         ORDER BY p.id_pregunta ASC`,
        [idsSeccion]
      ),
      db.query(
        `SELECT i.id_examen,
                COUNT(*)::int AS total_intentos,
                MAX(i.calificacion) AS mejor_calificacion,
                (ARRAY_AGG(i.calificacion ORDER BY i.numero_intento DESC))[1] AS ultima_calificacion,
                MAX(i.fecha_realizacion) AS fecha_ultimo_intento
         FROM intento_examen i
         JOIN examen e ON e.id_examen = i.id_examen
         WHERE e.id_seccion = ANY($1::int[]) AND i.id_usuario = $2
         GROUP BY i.id_examen`,
        [idsSeccion, id_usuario]
      ),
    ]);

    const intentosPorExamen = new Map(
      attemptsQuery.rows.map((r) => [
        r.id_examen,
        {
          total_intentos: r.total_intentos,
          mejor_calificacion: Number(r.mejor_calificacion),
          ultima_calificacion: Number(r.ultima_calificacion),
          fecha_ultimo_intento: r.fecha_ultimo_intento,
        },
      ])
    );

    const preguntasPorExamen = new Map();
    for (const { id_examen, ...q } of questionsQuery.rows) {
      // Asegurar parsing JSON de opciones si retornó como String
      const pregunta = {
        ...q,
        opciones: typeof q.opciones === 'string' ? JSON.parse(q.opciones) : q.opciones,
      };
      if (!preguntasPorExamen.has(id_examen)) preguntasPorExamen.set(id_examen, []);
      preguntasPorExamen.get(id_examen).push(pregunta);
    }

    for (const sec of secciones) {
      sec.contenidos = contentQuery.rows
        .filter((c) => c.id_seccion === sec.id_seccion)
        .map(({ id_seccion, ...c }) => c);

      const examen = examQuery.rows.find((e) => e.id_seccion === sec.id_seccion);
      sec.examen = examen
        ? {
            id_examen: examen.id_examen,
            tiempo_duracion_minutos: examen.tiempo_duracion_minutos,
            preguntas: preguntasPorExamen.get(examen.id_examen) || [],
            intentos: intentosPorExamen.get(examen.id_examen) || null,
          }
        : null;
    }

    res.json({
      guia,
      secciones,
    });
  } catch (error) {
    console.error('Error al obtener detalles de la guía:', error);
    res.status(500).json({ message: 'Error interno al obtener los detalles del curso' });
  }
};

// 5. MARCAR SECCIÓN COMO COMPLETADA
exports.completeSection = async (req, res) => {
  const { id_seccion } = req.body;
  const id_usuario = req.user.id_usuario;

  try {
    await db.query(
      `INSERT INTO avance_seccion (id_seccion, id_usuario, completado, fecha_inicio, fecha_fin)
       VALUES ($1, $2, TRUE, NOW(), NOW())
       ON CONFLICT (id_seccion, id_usuario)
       DO UPDATE SET completado = TRUE,
            fecha_inicio = COALESCE(avance_seccion.fecha_fin, NOW()),
            fecha_fin = COALESCE(avance_seccion.fecha_fin, NOW())`,
      [id_seccion, id_usuario]
    );

    res.json({ message: 'Avance registrado exitosamente' });
  } catch (error) {
    console.error('Error al completar la sección:', error);
    res.status(500).json({ message: 'Error interno al registrar avance' });
  }
};

// 6. REGISTRAR INICIO DE SECCIÓN (solo la primera vez)
exports.startSection = async (req, res) => {
  const { id_seccion } = req.body;
  const id_usuario = req.user.id_usuario;

  try {
    await db.query(
      `INSERT INTO avance_seccion (id_seccion, id_usuario, completado, fecha_inicio)
       VALUES ($1, $2, FALSE, NOW())
       ON CONFLICT (id_seccion, id_usuario)
       DO UPDATE SET fecha_inicio = COALESCE(avance_seccion.fecha_inicio, NOW())`,
      [id_seccion, id_usuario]
    );
    res.json({ message: 'Inicio registrado' });
  } catch (error) {
    console.error('Error al registrar inicio de sección:', error);
    res.status(500).json({ message: 'Error interno al registrar inicio' });
  }
};
exports.deleteGuide = async (req, res) => {
  const idGuia = parseInt(req.params.id_guia, 10);
  const id_usuario = req.user.id_usuario;

  if (!Number.isInteger(idGuia)) {
    return res.status(400).json({ message: 'Guía no válida.' });
  }

  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const propia = await client.query(
      'SELECT id_guia FROM guia_estudio WHERE id_guia = $1 AND id_usuario = $2 FOR UPDATE',
      [idGuia, id_usuario]
    );
    if (propia.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'La guía no existe o ya fue eliminada.' });
    }

    const secciones = `SELECT id_seccion FROM seccion WHERE id_guia = $1`;
    const examenes = `SELECT id_examen FROM examen WHERE id_seccion IN (${secciones})`;

    await client.query(
      `DELETE FROM respuesta_usuario
       WHERE id_intento IN (SELECT id_intento FROM intento_examen WHERE id_examen IN (${examenes}))
          OR id_pregunta IN (SELECT id_pregunta FROM pregunta WHERE id_examen IN (${examenes}))`,
      [idGuia]
    );
    await client.query(`DELETE FROM intento_examen WHERE id_examen IN (${examenes})`, [idGuia]);
    await client.query(`DELETE FROM pregunta WHERE id_examen IN (${examenes})`, [idGuia]);
    await client.query(`DELETE FROM examen WHERE id_seccion IN (${secciones})`, [idGuia]);
    await client.query(`DELETE FROM contenido_seccion WHERE id_seccion IN (${secciones})`, [idGuia]);
    await client.query(`DELETE FROM avance_seccion WHERE id_seccion IN (${secciones})`, [idGuia]);
    await client.query('DELETE FROM seccion WHERE id_guia = $1', [idGuia]);
    await client.query('DELETE FROM guia_estudio WHERE id_guia = $1 AND id_usuario = $2', [idGuia, id_usuario]);

    await client.query('COMMIT');
    res.json({ message: 'Guía eliminada correctamente.' });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('Error al eliminar la guía:', error);
    res.status(500).json({ message: 'No se pudo eliminar la guía. Inténtalo de nuevo.' });
  } finally {
    client.release();
  }
};