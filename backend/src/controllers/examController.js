const db = require('../config/db');
const { Type } = require('@google/genai');
const { generarJSON, IANoDisponibleError, ThinkingLevel } = require('../services/geminiService');

const MAX_ERRORES_TUTOR = 15;
const MAX_TEORIA_POR_SECCION = 7000;
const INCISOS = ['A', 'B', 'C', 'D'];

const tutorSchema = {
  type: Type.OBJECT,
  properties: {
    resumen: { type: Type.STRING },
    temas_a_repasar: { type: Type.ARRAY, items: { type: Type.STRING } },
    errores: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          numero: { type: Type.INTEGER },
          concepto: { type: Type.STRING },
          por_que_es_incorrecta: { type: Type.STRING },
          explicacion: { type: Type.STRING },
          clave: { type: Type.STRING },
        },
        required: ['numero', 'concepto', 'por_que_es_incorrecta', 'explicacion', 'clave'],
      },
    },
  },
  required: ['resumen', 'temas_a_repasar', 'errores'],
};

// 1. Tutor de IA para explicar los fundamentos teóricos de los errores
// Devuelve `fundamentos` (estructurado, para la vista) y `respuesta` (texto plano, compatibilidad)
const texto = (v) => (typeof v === 'string' ? v.trim() : v == null ? '' : String(v).trim());

const sinMarkdown = (v) =>
  texto(v)
    .replace(/[*#`_]+/g, '')
    .replace(/\s+/g, ' ')
    .trim();

const normalizarClave = (v) =>
  texto(v)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const PALABRAS_VACIAS = new Set(
  'de la el los las un una unos unas y o en por para con sin que se su sus del al lo es son como mas pero si no cual cuales cuando donde este esta estos estas ese esa eso tu te mi le les ya muy hay ser fue sobre entre desde hasta tiene tienen puede pueden debe deben'.split(' ')
);

const palabras = (v) => normalizarClave(v).split(' ').filter((p) => p.length > 2 && !PALABRAS_VACIAS.has(p));

const parsearJSON = (v) => {
  if (v && typeof v === 'object') return v;
  try {
    return JSON.parse(v);
  } catch (_) {
    return null;
  }
};

const fundamentosATexto = (f) => {
  const partes = [];
  if (f.resumen) partes.push(f.resumen);
  (f.errores || []).forEach((e, i) => {
    partes.push(
      `${i + 1}. ${e.concepto || 'Concepto'}\n` +
      `Por qué es incorrecta: ${e.por_que_es_incorrecta || ''}\n` +
      `Fundamento: ${e.explicacion || ''}\n` +
      `Idea clave: ${e.clave || ''}`
    );
  });
  return partes.join('\n\n');
};

const separarRespuesta = (valor) => {
  const t = texto(valor);
  if (/^[A-Da-d]$/.test(t)) return { letra: t.toUpperCase(), texto: '' };
  const m = /^([A-Da-d])\s*[).:-]\s*(.*)$/s.exec(t);
  if (m) return { letra: m[1].toUpperCase(), texto: texto(m[2]) };
  return { letra: '', texto: /^no (respondida|especificada)$/i.test(t) ? '' : t };
};

const opcionesComoLista = (opciones) => {
  const lista = parsearJSON(opciones);
  if (!Array.isArray(lista)) return [];
  return lista
    .map((op, i) => ({
      inciso: texto(op && op.inciso).toUpperCase() || INCISOS[i],
      texto: texto(op && (op.texto || op.opcion)),
    }))
    .filter((op) => op.texto);
};

const fragmentosDeContenido = (titulo, contenido) => {
  const c = parsearJSON(contenido);
  if (!c || typeof c !== 'object') {
    const plano = texto(contenido);
    return plano ? [{ tema: titulo, tipo: 'texto', titulo, texto: plano.slice(0, 1200) }] : [];
  }
  const lista = [];
  if (c.introduccion) lista.push({ tema: titulo, tipo: 'intro', titulo, texto: texto(c.introduccion) });
  (Array.isArray(c.desarrollo) ? c.desarrollo : []).forEach((b) => {
    if (b && b.texto) lista.push({ tema: titulo, tipo: 'desarrollo', titulo: texto(b.subtitulo) || titulo, texto: texto(b.texto) });
  });
  (Array.isArray(c.conceptos) ? c.conceptos : []).forEach((x) => {
    if (x && x.explicacion) lista.push({ tema: titulo, tipo: 'concepto', titulo: texto(x.titulo), texto: texto(x.explicacion) });
  });
  if (c.ejemplo) lista.push({ tema: titulo, tipo: 'ejemplo', titulo, texto: texto(c.ejemplo) });
  if (c.resumen) lista.push({ tema: titulo, tipo: 'resumen', titulo, texto: texto(c.resumen) });
  return lista;
};

const teoriaComoTexto = (fragmentos) => {
  const porTema = new Map();
  fragmentos.forEach((f) => {
    if (!porTema.has(f.tema)) porTema.set(f.tema, []);
    const etiqueta = f.tipo === 'concepto' ? `Concepto ${f.titulo}` : f.tipo === 'desarrollo' ? f.titulo : f.tipo;
    porTema.get(f.tema).push(`  - ${etiqueta}: ${f.texto}`);
  });
  const salida = [...porTema.entries()].map(([tema, lineas]) => `Tema: ${tema}\n${lineas.join('\n')}`).join('\n\n');
  return salida.slice(0, MAX_TEORIA_POR_SECCION);
};

const cargarContexto = async (errores, id_usuario) => {
  const ids = errores.map((e) => parseInt(e.id_pregunta, 10)).filter(Number.isInteger);
  const enunciados = errores.map((e) => texto(e.pregunta || e.texto_pregunta)).filter(Boolean);
  if (!ids.length && !enunciados.length) return { preguntas: [], teoria: new Map() };

  const { rows: preguntas } = await db.query(
    `SELECT p.id_pregunta, p.pregunta, p.opciones, p.respuesta_correcta, e.id_seccion
     FROM pregunta p
     JOIN examen e ON e.id_examen = p.id_examen
     JOIN seccion s ON s.id_seccion = e.id_seccion
     JOIN guia_estudio g ON g.id_guia = s.id_guia
     WHERE g.id_usuario = $1
       AND (p.id_pregunta = ANY($2::int[]) OR p.pregunta = ANY($3::text[]))
     ORDER BY p.id_pregunta DESC`,
    [id_usuario, ids, enunciados]
  );

  const secciones = [...new Set(preguntas.map((p) => p.id_seccion))];
  const teoria = new Map();
  if (secciones.length) {
    const { rows } = await db.query(
      `SELECT id_seccion, titulo, contenido
       FROM contenido_seccion
       WHERE id_seccion = ANY($1::int[])
       ORDER BY id_seccion, orden_contenido ASC`,
      [secciones]
    );
    rows.forEach((r) => {
      if (!teoria.has(r.id_seccion)) teoria.set(r.id_seccion, []);
      teoria.get(r.id_seccion).push(...fragmentosDeContenido(r.titulo, r.contenido));
    });
  }
  return { preguntas, teoria };
};

const prepararErrores = (errores, contexto) =>
  errores.map((err) => {
    const id = parseInt(err.id_pregunta, 10);
    const enunciadoEnviado = texto(err.pregunta || err.texto_pregunta);
    const bd =
      contexto.preguntas.find((p) => Number.isInteger(id) && p.id_pregunta === id) ||
      contexto.preguntas.find((p) => p.pregunta === enunciadoEnviado) ||
      null;

    const opciones = bd ? opcionesComoLista(bd.opciones) : [];
    const usuario = separarRespuesta(err.respuesta_usuario);
    const correcta = separarRespuesta(err.respuesta_correcta);

    const letraCorrecta = bd ? texto(bd.respuesta_correcta).toUpperCase() : correcta.letra;
    const textoCorrecta =
      (opciones.find((o) => o.inciso === letraCorrecta) || {}).texto || correcta.texto || letraCorrecta;
    const textoUsuario =
      (usuario.letra && (opciones.find((o) => o.inciso === usuario.letra) || {}).texto) || usuario.texto;

    return {
      pregunta: bd ? bd.pregunta : enunciadoEnviado,
      opciones,
      letraUsuario: usuario.letra,
      textoUsuario,
      letraCorrecta,
      textoCorrecta,
      fragmentos: bd ? contexto.teoria.get(bd.id_seccion) || [] : [],
      id_seccion: bd ? bd.id_seccion : null,
    };
  });

const mejoresFragmentos = (e, cantidad = 2) => {
  const objetivo = new Set([...palabras(e.pregunta), ...palabras(e.textoCorrecta)]);
  return e.fragmentos
    .map((f, i) => {
      const ps = palabras(`${f.titulo} ${f.texto}`);
      const coincidencias = ps.filter((p) => objetivo.has(p)).length;
      const bono = f.tipo === 'concepto' ? 1.5 : f.tipo === 'desarrollo' ? 1 : 0;
      return { f, puntaje: coincidencias + (coincidencias ? bono : 0), i };
    })
    .filter((x) => x.puntaje > 0)
    .sort((a, b) => b.puntaje - a.puntaje || a.i - b.i)
    .slice(0, cantidad)
    .map((x) => x.f);
};

const primeraOracion = (v) => {
  const t = sinMarkdown(v);
  const m = /^(.+?[.!?])(\s|$)/.exec(t);
  return m ? m[1] : t;
};

const fundamentoDeRespaldo = (e, numero) => {
  const mejores = mejoresFragmentos(e);
  const concepto = mejores.find((f) => f.tipo === 'concepto');
  const correctaTxt = e.letraCorrecta && e.textoCorrecta !== e.letraCorrecta
    ? `${e.letraCorrecta}) ${e.textoCorrecta}`
    : e.textoCorrecta;

  const porQue = e.textoUsuario
    ? `Elegiste "${e.letraUsuario ? `${e.letraUsuario}) ` : ''}${e.textoUsuario}", pero esa opción no responde correctamente lo que plantea la pregunta. La respuesta correcta es "${correctaTxt}".`
    : `No respondiste esta pregunta. La respuesta correcta es "${correctaTxt}".`;

  const explicacion = mejores.length
    ? mejores.map((f) => sinMarkdown(f.texto)).join(' ')
    : `La opción correcta es "${e.textoCorrecta}". Vuelve a leer el tema de la sección donde se explica este punto para reforzarlo.`;

  const clave = concepto
    ? `${concepto.titulo}: ${primeraOracion(concepto.texto)}`
    : mejores.length
      ? primeraOracion(mejores[0].texto)
      : `Recuerda: ${e.textoCorrecta}`;

  const tituloConcepto = concepto ? concepto.titulo : mejores.length ? mejores[0].tema : 'Concepto evaluado';

  return {
    numero,
    concepto: tituloConcepto.split(/\s+/).slice(0, 6).join(' '),
    por_que_es_incorrecta: porQue,
    explicacion,
    clave,
    tema: mejores.length ? mejores[0].tema : '',
  };
};

const respaldoCompleto = (preparados) => {
  const errores = preparados.map((e, i) => fundamentoDeRespaldo(e, i + 1));
  const temas = [...new Set(errores.map((e) => e.tema).filter(Boolean))].slice(0, 5);
  return {
    resumen: temas.length
      ? `Repasa estos temas para reforzar lo que fallaste: ${temas.join(', ')}.`
      : 'Repasa los temas de la sección relacionados con las preguntas que fallaste.',
    temas_a_repasar: temas,
    errores: errores.map(({ tema, ...resto }) => resto),
  };
};

const construirPrompt = (preparados) => {
  const secciones = new Map();
  preparados.forEach((e) => {
    if (e.id_seccion && e.fragmentos.length && !secciones.has(e.id_seccion)) {
      secciones.set(e.id_seccion, teoriaComoTexto(e.fragmentos));
    }
  });

  const teoria = secciones.size
    ? `TEORÍA QUE EL ALUMNO ESTUDIÓ (fuente principal de tus explicaciones):\n${[...secciones.values()].join('\n\n')}\n\n`
    : '';

  const lista = preparados
    .map((e, i) => {
      const opciones = e.opciones.length
        ? `\n   Opciones: ${e.opciones.map((o) => `${o.inciso}) ${o.texto}`).join(' | ')}`
        : '';
      const eligio = e.textoUsuario
        ? `${e.letraUsuario ? `${e.letraUsuario}) ` : ''}${e.textoUsuario}`
        : 'No respondió';
      const correcta = e.letraCorrecta && e.textoCorrecta !== e.letraCorrecta
        ? `${e.letraCorrecta}) ${e.textoCorrecta}`
        : e.textoCorrecta;
      return `${i + 1}. Pregunta: "${e.pregunta}"${opciones}\n   Eligió: "${eligio}"\n   Correcta: "${correcta}"`;
    })
    .join('\n');

  return `Eres un sistema de retroalimentación académica. Explica de forma clara, sencilla y objetiva por qué cada respuesta del alumno es incorrecta y cuál es el fundamento teórico correcto.

${teoria}REGLAS OBLIGATORIAS:
1. La respuesta marcada como "Correcta" es la oficial: explícala y nunca la contradigas ni digas que otra opción también es válida.
2. Basa el fundamento en la TEORÍA de arriba: usa sus mismos conceptos, definiciones y cifras. Solo si un punto no aparece ahí, usa conocimiento general de finanzas personales que sea consistente con ella.
3. En "por_que_es_incorrecta" menciona lo que eligió el alumno y explica el error concreto de esa opción frente a la correcta. Si no respondió, dilo.
4. Lenguaje sencillo, como para un estudiante que ve el tema por primera vez. Frases cortas.
5. Sin saludos, despedidas ni frases de cortesía. Texto plano, sin markdown.
6. Formato:
   - "resumen": 1 o 2 frases sobre qué temas debe reforzar el alumno en general.
   - "temas_a_repasar": de 1 a 5 temas cortos.
   - "errores": exactamente ${preparados.length} elementos, en el mismo orden que la lista, con "numero" igual a su posición.
   - "concepto": nombre corto del concepto evaluado (máx. 5 palabras).
   - "por_que_es_incorrecta": 1 o 2 frases.
   - "explicacion": 2 a 4 frases con el fundamento teórico de la respuesta correcta.
   - "clave": una sola frase fácil de recordar.

ERRORES COMETIDOS:
${lista}`;
};

const combinar = (ia, respaldo) => {
  const recibidos = Array.isArray(ia && ia.errores) ? ia.errores : [];
  const porNumero = new Map();
  recibidos.forEach((e, i) => {
    const n = parseInt(e && e.numero, 10);
    porNumero.set(Number.isInteger(n) && n >= 1 && n <= respaldo.errores.length ? n : i + 1, e);
  });

  let usados = 0;
  const errores = respaldo.errores.map((base, i) => {
    const e = porNumero.get(i + 1) || recibidos[i];
    const campos = ['concepto', 'por_que_es_incorrecta', 'explicacion', 'clave'];
    if (!e || campos.some((c) => !sinMarkdown(e[c]))) return base;
    usados++;
    const limpio = { numero: i + 1 };
    campos.forEach((c) => (limpio[c] = sinMarkdown(e[c])));
    return limpio;
  });

  const temas = (Array.isArray(ia && ia.temas_a_repasar) ? ia.temas_a_repasar : []).map(sinMarkdown).filter(Boolean);
  return {
    fundamentos: {
      resumen: sinMarkdown(ia && ia.resumen) || respaldo.resumen,
      temas_a_repasar: temas.length ? temas.slice(0, 5) : respaldo.temas_a_repasar,
      errores,
    },
    usados,
  };
};

exports.askAiTutor = async (req, res) => {
  const { errores } = req.body || {};

  if (!Array.isArray(errores) || errores.length === 0) {
    return res.status(400).json({ success: false, message: 'No hay errores para analizar' });
  }

  const lista = errores.slice(0, MAX_ERRORES_TUTOR).map((e) => (e && typeof e === 'object' ? e : {}));
  let preparados;

  try {
    const contexto = await cargarContexto(lista, req.user.id_usuario).catch((err) => {
      console.warn('Tutor: no se pudo cargar la teoría de la guía:', err.message);
      return { preguntas: [], teoria: new Map() };
    });
    preparados = prepararErrores(lista, contexto);
    const respaldo = respaldoCompleto(preparados);

    let fundamentos = respaldo;
    let fuente = 'contenido';

    try {
      const ia = await generarJSON(construirPrompt(preparados), tutorSchema, {
        etiqueta: 'tutor',
        thinking: ThinkingLevel.MINIMAL,
        presupuestoMs: 30000,
        timeoutMs: 25000,
        validar: (d) => Array.isArray(d && d.errores) && d.errores.length > 0,
      });
      const combinado = combinar(ia, respaldo);
      fundamentos = combinado.fundamentos;
      fuente = combinado.usados === preparados.length ? 'ia' : combinado.usados ? 'mixta' : 'contenido';
    } catch (errIA) {
      console.warn(`Tutor: se usó la explicación basada en el contenido (${errIA instanceof IANoDisponibleError ? 'IA no disponible' : errIA.message}).`);
    }

    return res.status(200).json({
      success: true,
      fuente,
      fundamentos,
      respuesta: fundamentosATexto(fundamentos),
    });
  } catch (error) {
    console.error('Error en el tutor de IA:', error);
    const fundamentos = respaldoCompleto(preparados || prepararErrores(lista, { preguntas: [], teoria: new Map() }));
    return res.status(200).json({
      success: true,
      fuente: 'contenido',
      fundamentos,
      respuesta: fundamentosATexto(fundamentos),
    });
  }
};

// 2. Obtener las preguntas de un examen
exports.getExamQuestions = async (req, res) => {
  const { examId } = req.params;

  try {
    const questionsResult = await db.query(
      `SELECT id_pregunta, pregunta AS texto_pregunta, opciones 
       FROM pregunta 
       WHERE id_examen = $1 
       ORDER BY id_pregunta ASC`,
      [examId]
    );

    if (questionsResult.rows.length === 0) {
      return res.status(404).json({ message: 'No se encontraron preguntas para este examen' });
    }

    res.json({ preguntas: questionsResult.rows });
  } catch (error) {
    console.error('Error al obtener las preguntas:', error);
    res.status(500).json({ message: 'Error al obtener las preguntas' });
  }
};

// 3. Evaluar el examen, registrar el intento y devolver errores para la vista
exports.submitExam = async (req, res) => {
  const { examId } = req.params;
  const { respuestas } = req.body; 
  const id_usuario = req.user.id_usuario;

  try {
    if (!respuestas || !Array.isArray(respuestas) || respuestas.length === 0) {
      return res.status(400).json({ message: 'No se enviaron respuestas para evaluar' });
    }

    const porPregunta = new Map();
    for (const resp of respuestas) {
      const id = parseInt(resp && resp.id_pregunta, 10);
      if (Number.isInteger(id)) {
        porPregunta.set(id, resp.opcion_seleccionada ? String(resp.opcion_seleccionada).toUpperCase() : '');
      }
    }
    const ids = [...porPregunta.keys()];

    const { rows } = await db.query(
      `SELECT id_pregunta, pregunta, opciones, respuesta_correcta FROM pregunta
       WHERE id_examen = $1 AND id_pregunta = ANY($2::int[])`,
      [examId, ids]
    );
    const preguntasBD = new Map(rows.map((r) => [r.id_pregunta, r]));

    let respuestasCorrectas = 0;
    const totalPreguntas = respuestas.length;
    const detalleRespuestas = [];
    const erroresDelExamen = [];
    const examenCompleto = [];

    for (const [idPregunta, opcionSeleccionada] of porPregunta) {
      const row = preguntasBD.get(idPregunta);
      if (!row) continue;

      const respuestaCorrectaBD = row.respuesta_correcta;
      const esCorrecta = opcionSeleccionada === respuestaCorrectaBD;

      if (esCorrecta) {
        respuestasCorrectas++;
      } else {
        // Guardamos el detalle estructurado del error para la vista de resultados
        erroresDelExamen.push({
          id_pregunta: idPregunta,
          pregunta: row.pregunta,
          respuesta_usuario: opcionSeleccionada,
          respuesta_correcta: respuestaCorrectaBD,
        });
      }

      // Llenamos también el examen completo por si la IA necesita todo el contexto
      examenCompleto.push({
        pregunta: row.pregunta,
        opciones: row.opciones,
        respuesta_correcta: respuestaCorrectaBD,
      });

      detalleRespuestas.push({
        id_pregunta: idPregunta,
        opcion_seleccionada: opcionSeleccionada,
        es_correcta: esCorrecta,
      });
    }

    const calificacionPorcentaje = Number(((respuestasCorrectas / totalPreguntas) * 100).toFixed(2));

    const client = await db.connect();
    let idIntento;
    let numeroIntento;
    try {
      await client.query('BEGIN');

      const resultRecord = await client.query(
        `INSERT INTO intento_examen (id_examen, id_usuario, numero_intento, calificacion, fecha_realizacion)
         SELECT $1, $2, COALESCE(MAX(numero_intento), 0) + 1, $3, NOW()
         FROM intento_examen
         WHERE id_examen = $1 AND id_usuario = $2
         RETURNING id_intento, calificacion, numero_intento`,
        [examId, id_usuario, calificacionPorcentaje]
      );
      idIntento = resultRecord.rows[0].id_intento;
      numeroIntento = resultRecord.rows[0].numero_intento;

      if (detalleRespuestas.length) {
        await client.query(
          `INSERT INTO respuesta_usuario (id_pregunta, id_intento, opcion_seleccionada, es_correcta)
           SELECT t.id_pregunta, $1, t.opcion, t.correcta
           FROM unnest($2::int[], $3::text[], $4::boolean[]) AS t(id_pregunta, opcion, correcta)`,
          [
            idIntento,
            detalleRespuestas.map((d) => d.id_pregunta),
            detalleRespuestas.map((d) => d.opcion_seleccionada),
            detalleRespuestas.map((d) => d.es_correcta),
          ]
        );
      }

      await client.query('COMMIT');
    } catch (errTx) {
      await client.query('ROLLBACK').catch(() => {});
      throw errTx;
    } finally {
      client.release();
    }

    // Retornamos el resultado junto con los errores y el examen completo para Flutter
    return res.status(201).json({
      message: 'Examen evaluado exitosamente',
      resultado: {
        id_intento: idIntento,
        numero_intento: numeroIntento,
        calificacion: calificacionPorcentaje,
        correctas: respuestasCorrectas,
        incorrectas: totalPreguntas - respuestasCorrectas,
        totalPreguntas,
      },
      errores: erroresDelExamen,
      examen_completo: examenCompleto,
    });
  } catch (error) {
    console.error('Error al evaluar el examen:', error);
    return res.status(500).json({ message: 'Error al evaluar el examen' });
  }
};

const formatearRespuesta = (letra, opciones) => {
  const inciso = String(letra || '').trim().toUpperCase();
  if (!inciso) return 'No respondida';
  const lista = Array.isArray(opciones) ? opciones : (() => {
    try {
      return JSON.parse(opciones);
    } catch (_) {
      return [];
    }
  })();
  const opcion = (Array.isArray(lista) ? lista : []).find(
    (op) => String((op && op.inciso) || '').trim().toUpperCase() === inciso
  );
  const texto = String((opcion && (opcion.texto || opcion.opcion)) || '').trim();
  return texto ? `${inciso}) ${texto}` : inciso;
};

exports.getLastAttempt = async (req, res) => {
  const { examId } = req.params;
  const id_usuario = req.user.id_usuario;

  try {
    const intentoResult = await db.query(
      `SELECT id_intento, numero_intento, calificacion, fecha_realizacion
       FROM intento_examen
       WHERE id_examen = $1 AND id_usuario = $2
       ORDER BY numero_intento DESC
       LIMIT 1`,
      [examId, id_usuario]
    );

    if (intentoResult.rows.length === 0) {
      return res.status(404).json({ message: 'Todavía no has presentado este examen.' });
    }

    const intento = intentoResult.rows[0];
    const { rows } = await db.query(
      `SELECT p.id_pregunta, p.pregunta, p.opciones, p.respuesta_correcta, r.opcion_seleccionada, r.es_correcta
       FROM respuesta_usuario r
       JOIN pregunta p ON p.id_pregunta = r.id_pregunta
       WHERE r.id_intento = $1
       ORDER BY p.id_pregunta ASC`,
      [intento.id_intento]
    );

    const errores = [];
    const examenCompleto = [];
    let correctas = 0;

    rows.forEach((r) => {
      const respuestaUsuario = formatearRespuesta(r.opcion_seleccionada, r.opciones);
      const respuestaCorrecta = formatearRespuesta(r.respuesta_correcta, r.opciones);
      if (r.es_correcta) {
        correctas++;
      } else {
        errores.push({
          id_pregunta: r.id_pregunta,
          pregunta: r.pregunta,
          respuesta_usuario: respuestaUsuario,
          respuesta_correcta: respuestaCorrecta,
        });
      }
      examenCompleto.push({
        pregunta: r.pregunta,
        es_correcta: r.es_correcta === true,
        respuesta_usuario: respuestaUsuario,
        respuesta_correcta: respuestaCorrecta,
      });
    });

    return res.json({
      resultado: {
        id_intento: intento.id_intento,
        numero_intento: intento.numero_intento,
        calificacion: Number(intento.calificacion),
        correctas,
        incorrectas: rows.length - correctas,
        totalPreguntas: rows.length,
        fecha_realizacion: intento.fecha_realizacion,
      },
      errores,
      examen_completo: examenCompleto,
    });
  } catch (error) {
    console.error('Error al obtener el último intento:', error);
    return res.status(500).json({ message: 'No se pudieron cargar tus resultados.' });
  }
};