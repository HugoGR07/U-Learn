const db = require('../config/db');
const { GoogleGenAI, Type, ThinkingLevel } = require('@google/genai');

// Inicializar cliente de Google Gemini
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || process.env.OPENAI_API_KEY });

const MODELOS = [
  'models/gemini-3.5-flash',
  'models/gemini-3.6-flash',
  'models/gemini-3.7-flash'
];

const SECCIONES_POR_SEMANA = 3;
const TEMAS_POR_SECCION = 3;
const CONCEPTOS_POR_TEMA = 3;
const PREGUNTAS_POR_EXAMEN = 10;
const MINUTOS_POR_EXAMEN = 15;
const INCISOS = ['A', 'B', 'C', 'D'];
const INTENTOS_POR_SECCION = 2;
const TIMEOUT_MODELO_MS = parseInt(process.env.GEMINI_TIMEOUT_MS || '120000', 10);
const CONCURRENCIA = parseInt(process.env.GEMINI_CONCURRENCIA || '12', 10);

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
    secciones: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          titulo_seccion: { type: Type.STRING },
          objetivo: { type: Type.STRING },
          temas: { type: Type.ARRAY, items: { type: Type.STRING } },
        },
        required: ['titulo_seccion', 'objetivo', 'temas'],
      },
    },
  },
  required: ['secciones'],
};

const seccionSchema = {
  type: Type.OBJECT,
  properties: {
    temas: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          titulo: { type: Type.STRING },
          introduccion: { type: Type.STRING },
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
        },
        required: ['titulo', 'introduccion', 'conceptos', 'ejemplo', 'consejo', 'resumen'],
      },
    },
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
        },
        required: ['pregunta', 'opciones', 'respuesta_correcta'],
      },
    },
  },
  required: ['temas', 'preguntas'],
};

const llamarModelo = (modelName, prompt, schema, conThinking) =>
  ai.models.generateContent({
    model: modelName,
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      responseSchema: schema,
      abortSignal: AbortSignal.timeout(TIMEOUT_MODELO_MS),
      ...(conThinking ? { thinkingConfig: { thinkingLevel: ThinkingLevel.MEDIUM } } : {}),
    },
  });

const generarJSON = async (prompt, schema) => {
  let lastError = null;
  for (const modelName of MODELOS) {
    for (const conThinking of [true, false]) {
      try {
        const inicio = Date.now();
        const response = await llamarModelo(modelName, prompt, schema, conThinking);
        if (response && response.text) {
          console.log(`${modelName} respondió en ${Date.now() - inicio} ms`);
          return JSON.parse(response.text);
        }
        break;
      } catch (err) {
        lastError = err;
        const invalido = err.status === 400 || /thinking/i.test(err.message || '');
        console.warn(`Falló el modelo ${modelName} (${err.status || err.name || err.message}). Probando el siguiente...`);
        if (!(conThinking && invalido)) break;
      }
    }
  }
  throw lastError || new Error('No se pudo conectar con ningún modelo de Gemini.');
};

const limpiarTexto = (valor) => (typeof valor === 'string' ? valor.trim() : '');

const normalizarPregunta = (preg) => {
  const enunciado = limpiarTexto(preg && preg.pregunta);
  const opcionesRaw = Array.isArray(preg && preg.opciones) ? preg.opciones : [];
  const opciones = opcionesRaw
    .map((op) => limpiarTexto(op && (op.texto || op.opcion)))
    .filter(Boolean)
    .slice(0, INCISOS.length)
    .map((texto, i) => ({ inciso: INCISOS[i], texto }));

  if (!enunciado || opciones.length !== INCISOS.length) return null;

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
  return { pregunta: enunciado, opciones, respuesta_correcta: correcta };
};

const normalizarTema = (tema, plan) => {
  const titulo = limpiarTexto(tema && tema.titulo);
  const introduccion = limpiarTexto(tema && tema.introduccion);
  if (!titulo || !introduccion) return null;

  const conceptos = (Array.isArray(tema.conceptos) ? tema.conceptos : [])
    .map((c) => ({ titulo: limpiarTexto(c && c.titulo), explicacion: limpiarTexto(c && c.explicacion) }))
    .filter((c) => c.titulo && c.explicacion)
    .slice(0, plan.conceptos);

  return {
    titulo,
    contenido: {
      version: 2,
      introduccion,
      conceptos,
      ejemplo: limpiarTexto(tema.ejemplo),
      consejo: limpiarTexto(tema.consejo),
      resumen: limpiarTexto(tema.resumen),
    },
  };
};

const generarEstructura = async (tema, nivel, plan) => {
  const prompt = `Eres un experto educador en finanzas personales y diseñador instruccional.
Diseña el temario de un curso sobre "${tema}" para nivel "${nivel}", con duración de ${plan.semanas} semana(s) (${SECCIONES_POR_SEMANA} secciones por semana).

Reglas OBLIGATORIAS:
1. Exactamente ${plan.secciones} secciones progresivas (de lo básico a lo avanzado), sin repetir contenido entre ellas.
2. Cada sección tiene exactamente ${plan.temas} temas con títulos cortos y específicos (máximo 8 palabras).
3. "objetivo" es una sola oración que dice qué podrá hacer el estudiante al terminar la sección.
4. Todo en español neutro.`;

  for (let intento = 1; intento <= INTENTOS_POR_SECCION; intento++) {
    const data = await generarJSON(prompt, estructuraSchema);
    const secciones = (Array.isArray(data && data.secciones) ? data.secciones : [])
      .map((s) => ({
        titulo: limpiarTexto(s && s.titulo_seccion),
        objetivo: limpiarTexto(s && s.objetivo),
        temas: (Array.isArray(s && s.temas) ? s.temas : []).map(limpiarTexto).filter(Boolean).slice(0, plan.temas),
      }))
      .filter((s) => s.titulo && s.temas.length === plan.temas)
      .slice(0, plan.secciones);

    if (secciones.length === plan.secciones) return secciones;
    console.warn(`Estructura incompleta (intento ${intento}): ${secciones.length}/${plan.secciones} secciones válidas`);
  }
  throw new Error('Gemini no devolvió una estructura de curso válida.');
};

const generarSeccion = async (tema, nivel, plan, seccion, indice, todas) => {
  const temario = todas.map((s, i) => `${i + 1}. ${s.titulo}`).join('\n');
  const prompt = `Eres un experto educador en finanzas personales y diseñador instruccional.
Curso: "${tema}" | Nivel: "${nivel}" | Duración: ${plan.semanas} semana(s).

Temario completo del curso (solo como contexto, no repitas otras secciones):
${temario}

Desarrolla ÚNICAMENTE la sección ${indice + 1}: "${seccion.titulo}".
Objetivo de la sección: ${seccion.objetivo}

Temas a desarrollar, en este orden exacto:
${seccion.temas.map((t, i) => `${i + 1}. ${t}`).join('\n')}

Reglas OBLIGATORIAS para "temas" (exactamente ${plan.temas}, uno por cada tema listado y con el mismo título):
- "introduccion": un párrafo de 2 a 4 oraciones que explique de qué trata el tema y por qué importa.
- "conceptos": exactamente ${plan.conceptos} conceptos clave; cada uno con un "titulo" corto y una "explicacion" de 1 a 2 oraciones.
- "ejemplo": un caso práctico concreto con cifras en pesos mexicanos (MXN), de 2 a 3 oraciones.
- "consejo": una recomendación accionable de una oración.
- "resumen": una oración que sintetice lo más importante.
- Lenguaje claro y directo. Texto plano, sin Markdown, sin asteriscos ni viñetas.

Reglas OBLIGATORIAS para "preguntas" (examen de esta sección):
- Exactamente ${PREGUNTAS_POR_EXAMEN} preguntas de opción múltiple que evalúen SOLO los temas de esta sección.
- Cada pregunta con exactamente 4 opciones con incisos "A", "B", "C" y "D", en ese orden.
- "respuesta_correcta" es SOLO la letra del inciso correcto ("A", "B", "C" o "D").
- Solo una opción correcta por pregunta; distractores plausibles; reparte la respuesta correcta entre los cuatro incisos.
- Enunciados y opciones breves. Mezcla preguntas de comprensión, aplicación con cifras y análisis de casos.`;

  for (let intento = 1; intento <= INTENTOS_POR_SECCION; intento++) {
    try {
      const data = await generarJSON(prompt, seccionSchema);
      const temas = (Array.isArray(data && data.temas) ? data.temas : [])
        .map((t) => normalizarTema(t, plan))
        .filter(Boolean)
        .slice(0, plan.temas);
      const preguntas = (Array.isArray(data && data.preguntas) ? data.preguntas : [])
        .map(normalizarPregunta)
        .filter(Boolean)
        .slice(0, PREGUNTAS_POR_EXAMEN);

      if (temas.length === plan.temas && preguntas.length === PREGUNTAS_POR_EXAMEN) {
        return { ...seccion, temas, preguntas };
      }
      console.warn(
        `Sección ${indice + 1} incompleta (intento ${intento}): ${temas.length}/${plan.temas} temas, ${preguntas.length}/${PREGUNTAS_POR_EXAMEN} preguntas`
      );
    } catch (err) {
      console.warn(`Error generando la sección ${indice + 1} (intento ${intento}): ${err.message}`);
    }
  }
  throw new Error(`No se pudo generar la sección ${indice + 1} con ${PREGUNTAS_POR_EXAMEN} preguntas.`);
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
    const estructura = await generarEstructura(tema, nivelCurso, plan);

    const secciones = await mapConcurrente(estructura, CONCURRENCIA, (sec, i) =>
      generarSeccion(tema, nivelCurso, plan, sec, i, estructura)
    );

    const idGuia = await guardarCurso(id_usuario, idTema, secciones);
    console.log(`Guía ${idGuia} generada en ${Date.now() - inicio} ms (${secciones.length} secciones)`);

    res.status(201).json({
      message: 'Guía de estudio generada e insertada correctamente',
      id_guia: idGuia,
      curso: {
        semanas: plan.semanas,
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
    res.status(500).json({ message: 'Error interno al generar la guía con Gemini' });
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
        ), 0) AS examenes_pendientes
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

    const [contentQuery, examQuery, questionsQuery] = await Promise.all([
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
    ]);

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