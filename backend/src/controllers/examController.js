// src/controllers/examController.js
const db = require('../config/db');
const { GoogleGenAI } = require('@google/genai');

// Inicializamos el cliente oficial de Gemini usando tu GEMINI_API_KEY del .env
const ai = new GoogleGenAI();

exports.askAiTutor = async (req, res) => {
  try {
    const { prompt, examen_completo, errores } = req.body;

    // Construir el contexto detallado con todo el contenido del curso y examen
    let contextoCompletoCurso = `Eres un tutor académico experto en este curso. Tienes acceso completo a la información, teoría y reactivos del curso actual del alumno.\n\n`;

    if (examen_completo && examen_completo.length > 0) {
      contextoCompletoCurso += `=== CONTENIDO Y REACTIVOS TOTALES DEL EXAMEN/CURSO ===\n`;
      examen_completo.forEach((item, index) => {
        contextoCompletoCurso += `[Pregunta ${index + 1}]: ${item.pregunta || item.texto_pregunta}\n`;
        if (item.opciones) {
          contextoCompletoCurso += `Opciones: ${JSON.stringify(item.opciones)}\n`;
        }
        if (item.respuesta_correcta) {
          contextoCompletoCurso += `Respuesta Correcta Oficial: ${item.respuesta_correcta}\n`;
        }
        contextoCompletoCurso += `----\n`;
      });
    }

    if (errores && errores.length > 0) {
      contextoCompletoCurso += `\n=== ERRORES ESPECÍFICOS COMETIDOS POR EL ALUMNO ===\n`;
      errores.forEach((err, index) => {
        contextoCompletoCurso += `• Error ${index + 1}: Pregunta: "${err.pregunta}" | El alumno eligió: "${err.respuesta_usuario}" | La respuesta correcta es: "${err.respuesta_correcta}"\n`;
      });
    }

    contextoCompletoCurso += `\nInstrucción estricta: Analiza la pregunta que el alumno seleccionó para revisar. Relaciónala directamente con los datos teóricos y el contexto del curso que tienes arriba. Explícale detalladamente y con sólidos fundamentos teóricos por qué la respuesta correcta es la que es, y por qué la opción que eligió es incorrecta. No inventes información ajena al curso.`;

    // Llamada oficial a la API de Gemini utilizando el modelo estable y activo
    const response = await ai.models.generateContent({
      model: 'gemini-3.8-flash',
      contents: `${contextoCompletoCurso}\n\nConsulta del alumno: "${prompt}"`,
    });

    const respuestaTexto = response.text;

    return res.status(200).json({
      success: true,
      respuesta: respuestaTexto,
    });

  } catch (error) {
    console.error('Error en el tutor de IA (Gemini):', error);
    return res.status(500).json({
      success: false,
      message: 'Error al procesar la consulta con el tutor de IA',
    });
  }
};

// Obtener las preguntas de un examen
exports.getExamQuestions = async (req, res) => {
  const { examId } = req.params;

  try {
    const questionsResult = await db.query(
      `SELECT id_pregunta, pregunta AS texto_pregunta, opciones, respuesta_correcta 
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

// Evaluar el examen y registrar el intento del usuario
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

    for (const resp of respuestas) {
      const opcionSeleccionada = resp.opcion_seleccionada ? String(resp.opcion_seleccionada).toUpperCase() : '';

      const checkResult = await db.query(
        `SELECT respuesta_correcta FROM pregunta 
        WHERE id_pregunta = $1 AND id_examen = $2`,
        [resp.id_pregunta, examId]
      );

      if (checkResult.rows.length > 0) {
        const respuestaCorrectaBD = checkResult.rows[0].respuesta_correcta;
        const esCorrecta = (opcionSeleccionada === respuestaCorrectaBD);

        if (esCorrecta) {
          respuestasCorrectas++;
        }

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
    });
  } catch (error) {
    console.error('Error al evaluar el examen:', error);
    return res.status(500).json({ message: 'Error al evaluar el examen' });
  }
};