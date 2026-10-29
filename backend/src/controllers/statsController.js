const db = require('../config/db');

// Misma nota mínima que usan las vistas de Flutter (result_view / study_view)
const NOTA_APROBATORIA = 60;
const DIAS_ACTIVIDAD = 7;

const num = (v, def = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
};
const redondear = (v) => Math.round(num(v) * 10) / 10;

// Racha: días consecutivos con actividad terminando hoy (o ayer, para no
// romperla antes de que el usuario estudie en el día).
function calcularRacha(diasActivos) {
  const set = new Set(diasActivos);
  const dia = new Date();
  const clave = (d) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

  if (!set.has(clave(dia))) dia.setDate(dia.getDate() - 1);
  let racha = 0;
  while (set.has(clave(dia))) {
    racha++;
    dia.setDate(dia.getDate() - 1);
  }
  return racha;
}

// GET /api/stats/dashboard
exports.getDashboard = async (req, res) => {
  const idUsuario = req.user.id_usuario;

  try {
    const [cursosQ, intentosQ, respuestasQ, temasQ, recientesQ, actividadQ, diasQ, seccionesQ] =
      await Promise.all([
        // Una fila por curso (guía) con su avance y el promedio de sus mejores notas
        db.query(
          `SELECT g.id_guia,
                  t.nombre_tema,
                  (SELECT COUNT(*) FROM seccion s WHERE s.id_guia = g.id_guia)::int AS total_secciones,
                  (SELECT COUNT(*) FROM avance_seccion a
                     JOIN seccion s ON s.id_seccion = a.id_seccion
                    WHERE s.id_guia = g.id_guia AND a.id_usuario = $1 AND a.completado = TRUE)::int AS secciones_completadas,
                  (SELECT COUNT(*) FROM examen e
                     JOIN seccion s ON s.id_seccion = e.id_seccion
                    WHERE s.id_guia = g.id_guia)::int AS total_examenes,
                  m.presentados::int AS examenes_presentados,
                  m.promedio AS promedio
             FROM guia_estudio g
             JOIN tema t ON t.id_tema = g.id_tema
             LEFT JOIN LATERAL (
               SELECT COUNT(*) AS presentados, AVG(mejor) AS promedio
                 FROM (SELECT MAX(i.calificacion) AS mejor
                         FROM intento_examen i
                         JOIN examen e ON e.id_examen = i.id_examen
                         JOIN seccion s ON s.id_seccion = e.id_seccion
                        WHERE s.id_guia = g.id_guia AND i.id_usuario = $1
                        GROUP BY i.id_examen) x
             ) m ON TRUE
            WHERE g.id_usuario = $1`,
          [idUsuario]
        ),
        // Totales de intentos de examen
        db.query(
          `SELECT COUNT(*)::int AS total,
                  COUNT(*) FILTER (WHERE calificacion >= $2)::int AS aprobados,
                  COUNT(*) FILTER (WHERE calificacion < $2)::int AS reprobados,
                  AVG(calificacion) AS promedio,
                  MAX(calificacion) AS mejor
             FROM intento_examen WHERE id_usuario = $1`,
          [idUsuario, NOTA_APROBATORIA]
        ),
        // Precisión por pregunta
        db.query(
          `SELECT COUNT(*)::int AS total,
                  COUNT(*) FILTER (WHERE r.es_correcta)::int AS correctas
             FROM respuesta_usuario r
             JOIN intento_examen i ON i.id_intento = r.id_intento
            WHERE i.id_usuario = $1`,
          [idUsuario]
        ),
        // Rendimiento por tema (promedio de la mejor nota de cada examen)
        db.query(
          `SELECT nombre_tema, AVG(mejor) AS promedio, COUNT(*)::int AS examenes
             FROM (SELECT t.nombre_tema, MAX(i.calificacion) AS mejor
                     FROM intento_examen i
                     JOIN examen e ON e.id_examen = i.id_examen
                     JOIN seccion s ON s.id_seccion = e.id_seccion
                     JOIN guia_estudio g ON g.id_guia = s.id_guia
                     JOIN tema t ON t.id_tema = g.id_tema
                    WHERE i.id_usuario = $1
                    GROUP BY t.nombre_tema, i.id_examen) x
            GROUP BY nombre_tema
            ORDER BY promedio DESC`,
          [idUsuario]
        ),
        // Últimos exámenes presentados
        db.query(
          `SELECT t.nombre_tema, s.titulo AS seccion, i.calificacion,
                  i.numero_intento, i.fecha_realizacion
             FROM intento_examen i
             JOIN examen e ON e.id_examen = i.id_examen
             JOIN seccion s ON s.id_seccion = e.id_seccion
             JOIN guia_estudio g ON g.id_guia = s.id_guia
             JOIN tema t ON t.id_tema = g.id_tema
            WHERE i.id_usuario = $1
            ORDER BY i.fecha_realizacion DESC
            LIMIT 5`,
          [idUsuario]
        ),
        // Exámenes por día en la última semana
        db.query(
          `SELECT TO_CHAR(fecha_realizacion::date, 'YYYY-MM-DD') AS dia, COUNT(*)::int AS examenes
             FROM intento_examen
            WHERE id_usuario = $1 AND fecha_realizacion >= CURRENT_DATE - ($2::int - 1)
            GROUP BY 1`,
          [idUsuario, DIAS_ACTIVIDAD]
        ),
        // Días con actividad (examen o sección terminada) para la racha
        db.query(
          `SELECT DISTINCT TO_CHAR(dia, 'YYYY-MM-DD') AS dia FROM (
             SELECT fecha_realizacion::date AS dia FROM intento_examen WHERE id_usuario = $1
             UNION
             SELECT fecha_fin::date FROM avance_seccion
              WHERE id_usuario = $1 AND completado = TRUE AND fecha_fin IS NOT NULL
           ) d`,
          [idUsuario]
        ),
        // Secciones completadas en total
        db.query(
          `SELECT COUNT(*)::int AS completadas
             FROM avance_seccion WHERE id_usuario = $1 AND completado = TRUE`,
          [idUsuario]
        ),
      ]);

    // Clasificación de cursos:
    //  - terminado = presentó todos sus exámenes
    //  - aprobado / reprobado según el promedio de sus mejores notas
    //  - en curso = el resto
    let aprobados = 0;
    let reprobados = 0;
    let enCurso = 0;
    let sinIniciar = 0;
    const detalle = [];

    for (const c of cursosQ.rows) {
      const totalExamenes = num(c.total_examenes);
      const presentados = num(c.examenes_presentados);
      const completadas = num(c.secciones_completadas);
      const promedio = c.promedio === null ? null : num(c.promedio);

      const terminado = totalExamenes > 0 && presentados >= totalExamenes;
      let estado;
      if (terminado) {
        estado = promedio >= NOTA_APROBATORIA ? 'aprobado' : 'reprobado';
        if (estado === 'aprobado') aprobados++;
        else reprobados++;
      } else {
        estado = 'en_curso';
        enCurso++;
        if (completadas === 0 && presentados === 0) sinIniciar++;
      }

      const pasos = num(c.total_secciones) + totalExamenes;
      const hechos = completadas + Math.min(presentados, totalExamenes);
      detalle.push({
        id_guia: c.id_guia,
        nombre_tema: c.nombre_tema,
        estado,
        progreso: pasos > 0 ? Math.min(1, hechos / pasos) : 0,
        promedio: promedio === null ? null : redondear(promedio),
      });
    }

    const mapaActividad = new Map(actividadQ.rows.map((r) => [r.dia, r.examenes]));
    const actividadSemanal = [];
    const hoy = new Date();
    for (let i = DIAS_ACTIVIDAD - 1; i >= 0; i--) {
      const d = new Date(hoy);
      d.setDate(hoy.getDate() - i);
      const dia = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      actividadSemanal.push({ dia, examenes: mapaActividad.get(dia) || 0 });
    }

    const intentos = intentosQ.rows[0];
    const respuestas = respuestasQ.rows[0];

    res.json({
      umbral_aprobatorio: NOTA_APROBATORIA,
      cursos: {
        tomados: cursosQ.rows.length,
        en_curso: enCurso,
        sin_iniciar: sinIniciar,
        aprobados,
        reprobados,
        detalle,
      },
      examenes: {
        presentados: num(intentos.total),
        aprobados: num(intentos.aprobados),
        reprobados: num(intentos.reprobados),
        promedio: intentos.promedio === null ? null : redondear(intentos.promedio),
        mejor: intentos.mejor === null ? null : redondear(intentos.mejor),
      },
      preguntas: {
        respondidas: num(respuestas.total),
        correctas: num(respuestas.correctas),
        precision:
          num(respuestas.total) > 0
            ? redondear((num(respuestas.correctas) / num(respuestas.total)) * 100)
            : null,
      },
      secciones_completadas: num(seccionesQ.rows[0].completadas),
      racha_dias: calcularRacha(diasQ.rows.map((r) => r.dia)),
      dias_activos: diasQ.rows.length,
      por_tema: temasQ.rows.map((r) => ({
        nombre_tema: r.nombre_tema,
        promedio: redondear(r.promedio),
        examenes: r.examenes,
      })),
      actividad_semanal: actividadSemanal,
      ultimos_examenes: recientesQ.rows.map((r) => ({
        nombre_tema: r.nombre_tema,
        seccion: r.seccion,
        calificacion: redondear(r.calificacion),
        numero_intento: r.numero_intento,
        fecha: r.fecha_realizacion,
      })),
    });
  } catch (error) {
    console.error('Error en getDashboard:', error);
    res.status(500).json({ message: 'No pudimos cargar tus estadísticas' });
  }
};
