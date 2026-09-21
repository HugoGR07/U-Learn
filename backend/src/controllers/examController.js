// src/controllers/examController.js
const db = require('../config/db');

// Obtener las preguntas de un examen
exports.getExamQuestions = async (req, res) => {
  const { examId } = req.params;

  try {
    // Consulta preguntas de la tabla 'pregunta' asociadas al examen
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

// Evaluar el examen y registrar el intento del usuario
exports.submitExam = async (req, res) => {
  const { examId } = req.params;
  const { respuestas } = req.body; // Se espera un array de { id_pregunta, opcion_seleccionada }
  const id_usuario = req.user.id_usuario;

  try {
    if (!respuestas || !Array.isArray(respuestas) || respuestas.length === 0) {
      return res.status(400).json({ message: 'No se enviaron respuestas para evaluar' });
    }

    let respuestasCorrectas = 0;
    const totalPreguntas = respuestas.length;
    const detalleRespuestas = [];

    // 1. Obtener la respuesta correcta de cada pregunta enviada
    for (const resp of respuestas) {
      // Aseguramos que la opción seleccionada sea un string válido de 1 carácter
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

    // 2. Calcular el número de intento para este usuario en este examen
    const intentoResult = await db.query(
      `SELECT COALESCE(MAX(numero_intento), 0) + 1 AS siguiente_intento 
       FROM intento_examen 
       WHERE id_examen = $1 AND id_usuario = $2`,
      [examId, id_usuario]
    );
    const numeroIntento = intentoResult.rows[0].siguiente_intento;

    // 3. Registrar el intento en la tabla 'intento_examen'
    const resultRecord = await db.query(
      `INSERT INTO intento_examen (id_examen, id_usuario, numero_intento, calificacion, fecha_realizacion)
       VALUES ($1, $2, $3, $4, NOW()) 
       RETURNING id_intento, calificacion, numero_intento`,
      [examId, id_usuario, numeroIntento, calificacionPorcentaje]
    );

    const idIntento = resultRecord.rows[0].id_intento;

    // 4. Registrar el detalle de cada respuesta en la tabla 'respuesta_usuario'
    for (const det of detalleRespuestas) {
      await db.query(
        `INSERT INTO respuesta_usuario (id_pregunta, id_intento, opcion_seleccionada, es_correcta)
         VALUES ($1, $2, $3, $4)`,
        [det.id_pregunta, idIntento, det.opcion_seleccionada, det.es_correcta]
      );
    }

    // 5. Retornar el resultado al cliente Flutter
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