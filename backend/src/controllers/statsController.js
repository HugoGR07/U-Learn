const db = require('../config/db');

// Misma nota mínima que usan las vistas de Flutter (result_view / study_view)
const NOTA_APROBATORIA = 60;

const num = (v, def = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
};
const redondear = (v) => Math.round(num(v) * 10) / 10;

// La base guarda las fechas en UTC (timestamp sin zona). Para contar "días"
// como los ve el usuario, el cliente manda su desfase en minutos respecto a UTC.
const leerDesfase = (req) => {
  const n = parseInt(req.query.tz_offset, 10);
  return Number.isFinite(n) ? Math.max(-840, Math.min(840, n)) : 0;
};

// Racha: días consecutivos con actividad terminando hoy (o ayer, para no
// romperla antes de que el usuario estudie en el día).
function calcularRacha(diasActivos, desfaseMin) {
  const set = new Set(diasActivos);
  const DIA_MS = 24 * 60 * 60 * 1000;
  let t = Date.now() + desfaseMin * 60 * 1000;
  const clave = (ms) => new Date(ms).toISOString().slice(0, 10);

  if (!set.has(clave(t))) t -= DIA_MS;
  let racha = 0;
  while (set.has(clave(t))) {
    racha++;
    t -= DIA_MS;
  }
  return racha;
}

// Estado de un curso según sus exámenes:
//  - reprobado: ya presentó exámenes y el promedio de sus mejores notas es < 60
//    (si lo repite y mejora, deja de estar reprobado)
//  - aprobado:  presentó todos sus exámenes y el promedio es >= 60
//  - en_curso:  el resto (incluye los que aún no empiezan)
function clasificarCurso({ totalExamenes, presentados, promedio }) {
  if (presentados > 0 && promedio !== null && promedio < NOTA_APROBATORIA) return 'reprobado';
  if (totalExamenes > 0 && presentados >= totalExamenes) return 'aprobado';
  return 'en_curso';
}

// GET /api/stats/dashboard?tz_offset=<minutos respecto a UTC>
exports.getDashboard = async (req, res) => {
  const idUsuario = req.user.id_usuario;
  const desfase = leerDesfase(req);

  try {
    const [cursosQ, examenesQ, respuestasQ, evolucionQ, diasQ] = await Promise.all([
      // Una fila por curso con su avance y el promedio de sus mejores notas
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
          WHERE g.id_usuario = $1
          ORDER BY g.fecha_creacion DESC`,
        [idUsuario]
      ),
      // Promedio y mejor nota (la mejor de cada examen) y total de intentos
      db.query(
        `SELECT COUNT(*)::int AS examenes,
                AVG(mejor) AS promedio,
                MAX(mejor) AS mejor,
                COALESCE(SUM(intentos), 0)::int AS intentos
           FROM (SELECT MAX(calificacion) AS mejor, COUNT(*) AS intentos
                   FROM intento_examen WHERE id_usuario = $1
                  GROUP BY id_examen) x`,
        [idUsuario]
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
      // Evolución: últimos 10 intentos, de más viejo a más nuevo
      db.query(
        `SELECT calificacion FROM (
           SELECT calificacion, fecha_realizacion
             FROM intento_examen WHERE id_usuario = $1
            ORDER BY fecha_realizacion DESC LIMIT 10) x
          ORDER BY fecha_realizacion ASC`,
        [idUsuario]
      ),
      // Días con actividad (examen o sección terminada), en la zona del usuario
      db.query(
        `SELECT DISTINCT TO_CHAR(dia, 'YYYY-MM-DD') AS dia FROM (
           SELECT (fecha_realizacion + make_interval(mins => $2::int))::date AS dia
             FROM intento_examen WHERE id_usuario = $1
           UNION
           SELECT (fecha_fin + make_interval(mins => $2::int))::date
             FROM avance_seccion
            WHERE id_usuario = $1 AND completado = TRUE AND fecha_fin IS NOT NULL
         ) d`,
        [idUsuario, desfase]
      ),
    ]);

    const conteo = { en_curso: 0, aprobados: 0, reprobados: 0 };
    const detalle = cursosQ.rows.map((c) => {
      const totalExamenes = num(c.total_examenes);
      const presentados = num(c.examenes_presentados);
      const completadas = num(c.secciones_completadas);
      const promedio = c.promedio === null ? null : num(c.promedio);

      const estado = clasificarCurso({ totalExamenes, presentados, promedio });
      if (estado === 'aprobado') conteo.aprobados++;
      else if (estado === 'reprobado') conteo.reprobados++;
      else conteo.en_curso++;

      const pasos = num(c.total_secciones) + totalExamenes;
      const hechos = completadas + Math.min(presentados, totalExamenes);
      return {
        id_guia: c.id_guia,
        nombre_tema: c.nombre_tema,
        estado,
        progreso: pasos > 0 ? Math.min(1, hechos / pasos) : 0,
        promedio: promedio === null ? null : redondear(promedio),
      };
    });

    const ex = examenesQ.rows[0];
    const pr = respuestasQ.rows[0];
    const totalPreguntas = num(pr.total);

    res.json({
      umbral_aprobatorio: NOTA_APROBATORIA,
      cursos: {
        tomados: detalle.length,
        ...conteo,
        detalle,
      },
      examenes: {
        presentados: num(ex.examenes),
        intentos: num(ex.intentos),
        promedio: ex.promedio === null ? null : redondear(ex.promedio),
        mejor: ex.mejor === null ? null : redondear(ex.mejor),
      },
      precision: totalPreguntas > 0 ? redondear((num(pr.correctas) / totalPreguntas) * 100) : null,
      racha_dias: calcularRacha(diasQ.rows.map((r) => r.dia), desfase),
      evolucion_notas: evolucionQ.rows.map((r) => redondear(r.calificacion)),
    });
  } catch (error) {
    console.error('Error en getDashboard:', error);
    res.status(500).json({ message: 'No pudimos cargar tus estadísticas' });
  }
};
