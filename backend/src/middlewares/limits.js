const rateLimit = require('express-rate-limit');
const db = require('../config/db');

const GUIAS_POR_DIA = parseInt(process.env.GUIAS_POR_DIA || '5', 10);
const TUTOR_POR_HORA = parseInt(process.env.TUTOR_POR_HORA || '20', 10);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'Demasiados intentos. Intenta de nuevo en 15 minutos.' },
});

const tutorLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: TUTOR_POR_HORA,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => `usuario-${req.user.id_usuario}`,
  message: { message: 'Llegaste al límite de consultas al tutor. Intenta en una hora.' },
});

const guideDailyLimit = async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT COUNT(*)::int AS total
       FROM guia_estudio
       WHERE id_usuario = $1 AND fecha_creacion >= NOW() - INTERVAL '24 hours'`,
      [req.user.id_usuario]
    );
    if (rows[0].total >= GUIAS_POR_DIA) {
      return res.status(429).json({
        message: `Solo puedes generar ${GUIAS_POR_DIA} cursos cada 24 horas. Intenta más tarde.`,
      });
    }
    next();
  } catch (e) {
    console.error('Error verificando límite de guías:', e);
    res.status(500).json({ message: 'Error al verificar el límite de cursos' });
  }
};

module.exports = { authLimiter, tutorLimiter, guideDailyLimit };