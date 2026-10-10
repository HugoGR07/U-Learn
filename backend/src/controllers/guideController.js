const db = require('../config/db');
const { GoogleGenAI, Type } = require('@google/genai');

// Inicializar cliente de Google Gemini
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || process.env.OPENAI_API_KEY });

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

    // B. Definir el Esquema JSON estricto para Gemini
    const cursoSchema = {
      type: Type.OBJECT,
      properties: {
        secciones: {
          type: Type.ARRAY,
          items: {
            type: Type.OBJECT,
            properties: {
              titulo_seccion: { type: Type.STRING },
              orden_seccion: { type: Type.INTEGER },
              contenidos: {
                type: Type.ARRAY,
                items: {
                  type: Type.OBJECT,
                  properties: {
                    titulo_contenido: { type: Type.STRING },
                    contenido: { type: Type.STRING },
                    orden_contenido: { type: Type.INTEGER },
                  },
                  required: ['titulo_contenido', 'contenido', 'orden_contenido'],
                },
              },
              examen: {
                type: Type.OBJECT,
                properties: {
                  tiempo_duracion_minutos: { type: Type.INTEGER },
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
                              inciso: { type: Type.STRING },
                              texto: { type: Type.STRING },
                            },
                            required: ['inciso', 'texto'],
                          },
                        },
                        respuesta_correcta: { type: Type.STRING },
                      },
                      required: ['pregunta', 'opciones', 'respuesta_correcta'],
                    },
                  },
                },
                required: ['tiempo_duracion_minutos', 'preguntas'],
              },
            },
            required: ['titulo_seccion', 'orden_seccion', 'contenidos', 'examen'],
          },
        },
      },
      required: ['secciones'],
    };

    // C. Definición del Prompt Optimizado
    const semanas = duracion_semanas || 4;
    const promptText = `Eres un experto educador y diseñador instruccional.
Genera un curso/guía de estudio estructurado y detallado sobre el tema: "${tema}" para un nivel de dificultad: "${nivel || 'Intermedio'}".
El curso está programado para una duración estimada de ${semanas} semanas.

Requisitos OBLIGATORIOS de la guía:
1. Genera entre 4 y 6 secciones/módulos completos y progresivos para cubrir el tema en profundidad.
2. Cada sección DEBE incluir de 2 a 3 temas o contenidos instructivos bien explicados y educativos.
3. CADA SECCIÓN DEBE TENER SU PROPIO EXAMEN EVALUATIVO OBLIGATORIO al final.
4. Cada examen debe contener exactamente 10 preguntas de opción múltiple (con incisos A, B, C, D) e indicar claramente la "respuesta_correcta" (ejemplo: "A" o el texto exacto de la respuesta).`;

    // Lista de modelos oficial para @google/genai
    const modelsToTry = [
      'models/gemini-3.5-flash',
      'models/gemini-3.6-flash',
      'models/gemini-3.7-flash'
    ];

    let response = null;
    let lastError = null;

    for (const modelName of modelsToTry) {
      try {
        console.log(`Intentando generar curso con modelo: ${modelName}...`);
        response = await ai.models.generateContent({
          model: modelName,
          contents: promptText,
          config: {
            responseMimeType: 'application/json',
            responseSchema: cursoSchema,
          },
        });

        if (response && response.text) {
          console.log(`¡Éxito generando con el modelo ${modelName}!`);
          break;
        }
      } catch (err) {
        console.warn(`Falló el modelo ${modelName} (${err.status || err.message}). Probando el siguiente...`);
        lastError = err;
      }
    }

    if (!response || !response.text) {
      throw lastError || new Error('No se pudo conectar con ningún modelo de Gemini.');
    }

    const courseData = JSON.parse(response.text);

    // D. Insertar en PostgreSQL
    const guideResult = await db.query(
      `INSERT INTO guia_estudio (id_usuario, id_tema, fecha_creacion)
       VALUES ($1, $2, NOW())
       RETURNING id_guia`,
      [id_usuario, idTema]
    );
    const idGuia = guideResult.rows[0].id_guia;

    for (const sec of courseData.secciones) {
      // Insertar Sección
      const secResult = await db.query(
        `INSERT INTO seccion (id_guia, titulo, orden_seccion)
         VALUES ($1, $2, $3)
         RETURNING id_seccion`,
        [idGuia, sec.titulo_seccion, sec.orden_seccion]
      );
      const idSeccion = secResult.rows[0].id_seccion;

      // Registrar avance inicial
      await db.query(
        `INSERT INTO avance_seccion (id_seccion, id_usuario, completado)
         VALUES ($1, $2, FALSE)
         ON CONFLICT (id_usuario, id_seccion) DO NOTHING`,
        [idSeccion, id_usuario]
      );

      // Insertar Contenidos
      for (const cont of sec.contenidos) {
        await db.query(
          `INSERT INTO contenido_seccion (id_seccion, titulo, contenido, orden_contenido)
           VALUES ($1, $2, $3, $4)`,
          [idSeccion, cont.titulo_contenido, cont.contenido, cont.orden_contenido]
        );
      }

      // Insertar Examen
      if (sec.examen && sec.examen.preguntas && sec.examen.preguntas.length > 0) {
        const examResult = await db.query(
          `INSERT INTO examen (id_seccion, tiempo_duracion_minutos)
           VALUES ($1, $2)
           RETURNING id_examen`,
          [idSeccion, sec.examen.tiempo_duracion_minutos || 15]
        );
        const idExamen = examResult.rows[0].id_examen;

        for (const preg of sec.examen.preguntas) {
          await db.query(
            `INSERT INTO pregunta (id_examen, pregunta, opciones, respuesta_correcta)
             VALUES ($1, $2, $3, $4)`,
            [
              idExamen, 
              preg.pregunta, 
              typeof preg.opciones === 'string' ? preg.opciones : JSON.stringify(preg.opciones), 
              preg.respuesta_correcta
            ]
          );
        }
      }
    }

    res.status(201).json({
      message: 'Guía de estudio generada e insertada correctamente',
      id_guia: idGuia,
      curso: courseData,
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
        ), 0) AS secciones_completadas
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
    for (let sec of secciones) {
      const contentQuery = await db.query(
        `SELECT id_contenido, titulo, contenido, orden_contenido
         FROM contenido_seccion
         WHERE id_seccion = $1
         ORDER BY orden_contenido ASC`,
        [sec.id_seccion]
      );
      sec.contenidos = contentQuery.rows;

      const examQuery = await db.query(
        `SELECT id_examen, tiempo_duracion_minutos
         FROM examen
         WHERE id_seccion = $1`,
        [sec.id_seccion]
      );

      if (examQuery.rows.length > 0) {
        const id_examen = examQuery.rows[0].id_examen;
        const questionsQuery = await db.query(
          `SELECT id_pregunta, pregunta, opciones, respuesta_correcta
           FROM pregunta
           WHERE id_examen = $1`,
          [id_examen]
        );

        // Asegurar parsing JSON de opciones si retornó como String
        const preguntasFormateadas = questionsQuery.rows.map((q) => ({
          ...q,
          opciones: typeof q.opciones === 'string' ? JSON.parse(q.opciones) : q.opciones,
        }));

        sec.examen = {
          id_examen,
          tiempo_duracion_minutos: examQuery.rows[0].tiempo_duracion_minutos,
          preguntas: preguntasFormateadas,
        };
      } else {
        sec.examen = null;
      }
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
      `INSERT INTO avance_seccion (id_seccion, id_usuario, completado)
       VALUES ($1, $2, TRUE)
       ON CONFLICT (id_seccion, id_usuario)
       DO UPDATE SET completado = TRUE`,
      [id_seccion, id_usuario]
    );

    res.json({ message: 'Avance registrado exitosamente' });
  } catch (error) {
    console.error('Error al completar la sección:', error);
    res.status(500).json({ message: 'Error interno al registrar avance' });
  }
};