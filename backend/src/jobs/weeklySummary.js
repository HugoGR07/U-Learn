const cron = require('node-cron');
const db = require('../config/db');
const { sendMail } = require('../services/mailService');

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const group = (rows) => {
  const m = new Map();
  for (const r of rows) {
    if (!m.has(r.id_usuario)) m.set(r.id_usuario, []);
    m.get(r.id_usuario).push(r);
  }
  return m;
};

async function loadData(idUsuario) {
  const f = idUsuario ? ' AND u.id_usuario = $1' : '';
  const p = idUsuario ? [idUsuario] : [];

  const [users, guides, week, exams, pending] = await Promise.all([
    db.query(`SELECT u.id_usuario, u.nombre, u.correo FROM usuario u
              WHERE u.notif_correo = TRUE${f}`, p),

    db.query(`
      SELECT g.id_usuario, g.id_guia, t.nombre_tema,
             COUNT(s.id_seccion)::int AS total,
             (COUNT(a.id_seccion) FILTER (WHERE a.completado))::int AS hechas,
             MAX(a.fecha_fin) FILTER (WHERE a.completado) AS ultima
      FROM guia_estudio g
      JOIN usuario u ON u.id_usuario = g.id_usuario AND u.notif_correo = TRUE${f}
      JOIN tema t ON t.id_tema = g.id_tema
      LEFT JOIN seccion s ON s.id_guia = g.id_guia
      LEFT JOIN avance_seccion a ON a.id_seccion = s.id_seccion AND a.id_usuario = g.id_usuario
      GROUP BY g.id_usuario, g.id_guia, t.nombre_tema, g.fecha_creacion
      ORDER BY g.fecha_creacion DESC`, p),

    db.query(`
      SELECT a.id_usuario, COUNT(*)::int AS secciones_semana
      FROM avance_seccion a
      JOIN usuario u ON u.id_usuario = a.id_usuario AND u.notif_correo = TRUE${f}
      WHERE a.completado AND a.fecha_fin >= NOW() - INTERVAL '7 days'
      GROUP BY a.id_usuario`, p),

    db.query(`
      SELECT i.id_usuario, COUNT(*)::int AS intentos
      FROM intento_examen i
      JOIN usuario u ON u.id_usuario = i.id_usuario AND u.notif_correo = TRUE${f}
      WHERE i.fecha_realizacion >= NOW() - INTERVAL '7 days'
      GROUP BY i.id_usuario`, p),

    db.query(`
      SELECT g.id_usuario, COUNT(e.id_examen)::int AS examenes_pendientes
      FROM guia_estudio g
      JOIN usuario u ON u.id_usuario = g.id_usuario AND u.notif_correo = TRUE${f}
      JOIN seccion s ON s.id_guia = g.id_guia
      JOIN examen e ON e.id_seccion = s.id_seccion
      WHERE NOT EXISTS (
        SELECT 1 FROM intento_examen i
        WHERE i.id_examen = e.id_examen AND i.id_usuario = g.id_usuario)
      GROUP BY g.id_usuario`, p),
  ]);

  return {
    users: users.rows,
    guides: group(guides.rows),
    week: new Map(week.rows.map((r) => [r.id_usuario, r])),
    exams: new Map(exams.rows.map((r) => [r.id_usuario, r])),
    pending: new Map(pending.rows.map((r) => [r.id_usuario, r])),
  };
}

function buildEmail(user, guias, week, exam, pend) {
  const nombre = esc(user.nombre);
  const lecciones = week?.secciones_semana ?? 0;
  const examenes = exam?.intentos ?? 0;
  const exPend = pend?.examenes_pendientes ?? 0;
  const hace7dias = Date.now() - 7 * 24 * 60 * 60 * 1000;

  const conPct = guias.map((g) => ({
    ...g,
    falta: Math.max(g.total - g.hechas, 0),
    pct: g.total > 0 ? Math.round((g.hechas / g.total) * 100) : 0,
  }));
  const guiasSemana = conPct.filter(
    (g) => g.total > 0 && g.falta === 0 && g.ultima && new Date(g.ultima).getTime() >= hace7dias
  ).length;
  const secPend = conPct.reduce((n, g) => n + g.falta, 0);

  const asunto = 'Tu semana en U-Learn';

  const fila = (etiqueta, valor) => `
    <tr>
      <td style="padding:6px 0;font-size:14px;color:#475569">${etiqueta}</td>
      <td style="padding:6px 0;font-size:18px;font-weight:bold;color:#1D61E7;text-align:right">${valor}</td>
    </tr>`;

  const bloqueSemana = `
    <h3 style="color:#1E293B;font-size:15px;margin:20px 0 6px">Esta semana completaste:</h3>
    <div style="background:#F1F5F9;border-radius:12px;padding:8px 16px">
      <table width="100%" cellpadding="0" cellspacing="0">
        ${fila('Guías', guiasSemana)}
        ${fila('Exámenes', examenes)}
        ${fila('Lecciones', lecciones)}
      </table>
    </div>`;

  const barras = conPct.slice(0, 4).map((g) => `
    <tr><td style="padding:8px 0">
      <div style="font-size:14px;color:#1E293B;font-weight:600">${esc(g.nombre_tema)}
        <span style="float:right;color:#64748B;font-weight:400">${g.hechas}/${g.total} · ${g.pct}%</span></div>
      <div style="background:#E2E8F0;border-radius:6px;height:8px;margin-top:6px">
        <div style="background:#1D61E7;width:${g.pct}%;height:8px;border-radius:6px"></div></div>
    </td></tr>`).join('');

  const bloquePendientes = (secPend + exPend) > 0 ? `
    <h3 style="color:#1E293B;font-size:15px;margin:24px 0 8px">Pendientes</h3>
    <table width="100%" cellpadding="0" cellspacing="0"><tr>
      <td width="50%" style="padding-right:6px">
        <div style="background:#F1F5F9;border-radius:12px;padding:14px;text-align:center">
          <div style="font-size:26px;font-weight:bold;color:#1D61E7">${secPend}</div>
          <div style="font-size:13px;color:#475569">${secPend === 1 ? 'sección por hacer' : 'secciones por hacer'}</div>
        </div>
      </td>
      <td width="50%" style="padding-left:6px">
        <div style="background:#F1F5F9;border-radius:12px;padding:14px;text-align:center">
          <div style="font-size:26px;font-weight:bold;color:#1D61E7">${exPend}</div>
          <div style="font-size:13px;color:#475569">${exPend === 1 ? 'examen por presentar' : 'exámenes por presentar'}</div>
        </div>
      </td>
    </tr></table>` : `
    <p style="color:#334155;font-size:14px;margin:24px 0 0">🎉 No tienes nada pendiente. ¡Todo al día!</p>`;

  const html = `
  <div style="background:#F8FAFC;padding:24px;font-family:Arial,Helvetica,sans-serif">
    <div style="max-width:560px;margin:auto;background:#fff;border-radius:16px;padding:28px">
      <div style="color:#1D61E7;font-weight:bold;font-size:18px">U-Learn</div>
      <h2 style="color:#1E293B;margin:16px 0 4px">Hola ${nombre} 👋</h2>

      ${bloqueSemana}

      <h3 style="color:#1E293B;font-size:15px;margin:24px 0 4px">Progreso</h3>
      <table width="100%" cellpadding="0" cellspacing="0">${barras}</table>

      ${bloquePendientes}

      <p style="color:#94A3B8;font-size:12px;margin-top:28px">Puedes desactivar este resumen en Perfil → Notificaciones → Alertas por Correo</p>
    </div>
  </div>`;

  return { asunto, html };
}

let running = false;

async function runWeeklySummary({ idUsuario } = {}) {
  if (running) return { enviados: 0, omitido: true };
  running = true;
  let enviados = 0;
  try {
    const d = await loadData(idUsuario);
    for (const u of d.users) {
      const guias = d.guides.get(u.id_usuario);
      if (!guias || guias.length === 0) continue;
      try {
        const { asunto, html } = buildEmail(
          u, guias, d.week.get(u.id_usuario), d.exams.get(u.id_usuario), d.pending.get(u.id_usuario));
        await sendMail(u.correo, asunto, html);
        enviados++;
      } catch (e) {
        console.error('Error enviando resumen a', u.correo, e.message);
      }
    }
  } catch (e) {
    console.error('Error en resumen semanal:', e);
  } finally {
    running = false;
  }
  return { enviados };
}

if (!process.env.VERCEL) {
  cron.schedule('0 9 * * 1', () => runWeeklySummary(), {
    timezone: 'America/Mexico_City',
  });
}

module.exports = { runWeeklySummary };