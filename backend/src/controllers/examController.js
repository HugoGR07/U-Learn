const db = require('../config/db');
const { generarContenido, IANoDisponibleError, MENSAJE_IA_SATURADA } = require('../services/geminiService');

// 1. Tutor de IA para explicar los fundamentos teóricos de los errores
// Devuelve `fundamentos` (estructurado, para la vista) y `respuesta` (texto plano, compatibilidad)
const limpiarJson = (texto) => {
  const sinFences = String(texto).replace(/```json|```/gi, '').trim();
  const ini = sinFences.indexOf('{');
  const fin = sinFences.lastIndexOf('}');
  if (ini === -1 || fin === -1) return null;
  try {
    return JSON.parse(sinFences.slice(ini, fin + 1));
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

exports.askAiTutor = async (req, res) => {
  try {
    const { errores } = req.body;

    if (!Array.isArray(errores) || errores.length === 0) {
      return res.status(400).json({ success: false, message: 'No hay errores para analizar' });
    }

    let contexto = `Eres un sistema de retroalimentación académica. Explica de forma clara, sencilla y objetiva por qué cada respuesta del alumno es incorrecta y cuál es el fundamento teórico correcto.
REGLAS OBLIGATORIAS:
1. Lenguaje sencillo, como para un estudiante que ve el tema por primera vez. Frases cortas.
2. NO incluyas saludos, despedidas ni frases de cortesía.
3. NO uses markdown (sin asteriscos, sin #, sin viñetas).
4. Responde ÚNICAMENTE con un JSON válido con esta forma exacta:
{
  "resumen": "1 o 2 frases sobre qué temas debe reforzar el alumno en general",
  "temas_a_repasar": ["tema corto", "tema corto"],
  "errores": [
    {
      "numero": 1,
      "concepto": "nombre corto del concepto evaluado (máx. 5 palabras)",
      "por_que_es_incorrecta": "1 o 2 frases explicando el error del alumno",
      "explicacion": "2 a 4 frases con el fundamento teórico de la respuesta correcta",
      "clave": "una sola frase fácil de recordar"
    }
  ]
}
El arreglo "errores" debe tener exactamente ${errores.length} elementos, en el mismo orden que la lista.\n\n`;

    contexto += `ERRORES COMETIDOS:\n`;
    errores.forEach((err, index) => {
      contexto += `${index + 1}. Pregunta: "${err.pregunta}" | Eligió: "${err.respuesta_usuario}" | Correcta: "${err.respuesta_correcta}"\n`;
    });

    const responseText = await generarContenido({
      contents: contexto,
      config: { responseMimeType: 'application/json' },
      etiqueta: 'tutor',
      presupuestoMs: 80000,
    });

    const fundamentos = limpiarJson(responseText);
    const valido = fundamentos && Array.isArray(fundamentos.errores);

    return res.status(200).json({
      success: true,
      fundamentos: valido ? fundamentos : null,
      respuesta: valido ? fundamentosATexto(fundamentos) : responseText,
    });

  } catch (error) {
    console.error('Error en el tutor de IA:', error);
    if (error instanceof IANoDisponibleError) {
      return res.status(503).json({ success: false, message: MENSAJE_IA_SATURADA });
    }
    return res.status(500).json({
      success: false,
      message: 'El tutor no pudo responder en este momento. Inténtalo de nuevo en unos minutos.',
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

    let respuestasCorrectas = 0;
    const totalPreguntas = respuestas.length;
    const detalleRespuestas = [];
    const erroresDelExamen = [];
    const examenCompleto = [];

    for (const resp of respuestas) {
      const opcionSeleccionada = resp.opcion_seleccionada ? String(resp.opcion_seleccionada).toUpperCase() : '';

      const checkResult = await db.query(
        `SELECT pregunta, opciones, respuesta_correcta FROM pregunta 
        WHERE id_pregunta = $1 AND id_examen = $2`,
        [resp.id_pregunta, examId]
      );

      if (checkResult.rows.length > 0) {
        const row = checkResult.rows[0];
        const respuestaCorrectaBD = row.respuesta_correcta;
        const textoPregunta = row.pregunta;
        const opcionesPregunta = row.opciones;
        const esCorrecta = (opcionSeleccionada === respuestaCorrectaBD);

        if (esCorrecta) {
          respuestasCorrectas++;
        } else {
          // Guardamos el detalle estructurado del error para la vista de resultados
          erroresDelExamen.push({
            pregunta: textoPregunta,
            respuesta_usuario: opcionSeleccionada,
            respuesta_correcta: respuestaCorrectaBD,
          });
        }

        // Llenamos también el examen completo por si la IA necesita todo el contexto
        examenCompleto.push({
          pregunta: textoPregunta,
          opciones: opcionesPregunta,
          respuesta_correcta: respuestaCorrectaBD,
        });

        detalleRespuestas.push({
          id_pregunta: resp.id_pregunta,
          opcion_seleccionada: opcionSeleccionada,
          es_correcta: esCorrecta,
        });
      }
    }

    const calificacionPorcentaje = Number(((respuestasCorrectas / totalPreguntas) * 100).toFixed(2));

    const intentoResult = await db.query(
      `SELECT COALESCE(MAX(numero_intento), 0) + 1 AS siguiente_intento 
       FROM intento_examen 
       WHERE id_examen = $1 AND id_usuario = $2`,
      [examId, id_usuario]
    );
    const numeroIntento = intentoResult.rows[0].siguiente_intento;

    const resultRecord = await db.query(
      `INSERT INTO intento_examen (id_examen, id_usuario, numero_intento, calificacion, fecha_realizacion)
       VALUES ($1, $2, $3, $4, NOW()) 
       RETURNING id_intento, calificacion, numero_intento`,
      [examId, id_usuario, numeroIntento, calificacionPorcentaje]
    );

    const idIntento = resultRecord.rows[0].id_intento;

    for (const det of detalleRespuestas) {
      await db.query(
        `INSERT INTO respuesta_usuario (id_pregunta, id_intento, opcion_seleccionada, es_correcta)
         VALUES ($1, $2, $3, $4)`,
        [det.id_pregunta, idIntento, det.opcion_seleccionada, det.es_correcta]
      );
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