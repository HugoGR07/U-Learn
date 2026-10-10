const db = require('../config/db');
const { GoogleGenAI } = require('@google/genai');

// Inicializamos el cliente oficial de Gemini usando tu GEMINI_API_KEY del .env
const ai = new GoogleGenAI();

// 1. Tutor de IA para explicar los fundamentos teóricos de los errores
exports.askAiTutor = async (req, res) => {
  try {
    const { prompt, examen_completo, errores } = req.body;

    let contexto = `Eres un sistema automatizado de retroalimentación académica. Tu única tarea es explicar de forma clara, directa y estrictamente objetiva por qué las respuestas del alumno son incorrectas y cuál es el fundamento teórico correcto. 
      REGLAS OBLIGATORIAS:
      1. Ve directo al grano con la explicación técnica y teórica de cada error.
      2. NO incluyas saludos, despedidas, frases de cortesía ni invitaciones a continuar conversando (prohibido decir cosas como "si tienes dudas", "avísame", "estoy aquí para ayudarte", etc.).
      3. Mantén un tono formal, académico y conciso.\n\n`;

    if (errores && errores.length > 0) {
      contexto += `ERRORES COMETIDOS:\n`;
      errores.forEach((err, index) => {
        contexto += `${index + 1}. Pregunta: "${err.pregunta}" | Eligió: "${err.respuesta_usuario}" | Correcta: "${err.respuesta_correcta}"\n`;
      });
    }

    const modelsToTry = [
      'models/gemini-3.5-flash',
      'models/gemini-3.6-flash',
      'models/gemini-3.7-flash'
    ];

    let responseText = null;

    for (const modelName of modelsToTry) {
      try {
        console.log(`Intentando consultar tutor con modelo: ${modelName}...`);
        const response = await ai.models.generateContent({
          model: modelName,
          contents: `${contexto}\n\nPor favor, genera la retroalimentación teórica global.`,
        });
        
        if (response && response.text) {
          responseText = response.text;
          console.log(`¡Éxito con el modelo ${modelName}!`);
          break;
        }
      } catch (modelError) {
        console.warn(`Falló el modelo ${modelName}. Probando el siguiente...`);
      }
    }

    if (!responseText) {
      throw new Error('Todos los modelos de Gemini fallaron o están saturados.');
    }

    return res.status(200).json({
      success: true,
      respuesta: responseText,
    });

  } catch (error) {
    console.error('Error en el tutor de IA:', error);
    return res.status(500).json({
      success: false,
      message: 'Error al procesar la consulta con el tutor de IA',
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