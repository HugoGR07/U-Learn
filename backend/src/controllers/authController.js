const db = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { sendMail } = require('../services/mailService');

// Registrar usuario
exports.register = async (req, res) => {
  const { nombre, apellido_paterno, apellido_materno, correo, contrasena } = req.body;

  try {
    // Validar si el correo ya existe
    const userExist = await db.query('SELECT * FROM usuario WHERE correo = $1', [correo]);
    if (userExist.rows.length > 0) {
      return res.status(400).json({ message: 'El correo ya está registrado' });
    }

    // Encriptar contraseña
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(contrasena, salt);

    // Insertar usuario
    const newUser = await db.query(
      `INSERT INTO usuario (nombre, apellido_paterno, apellido_materno, correo, contrasena)
       VALUES ($1, $2, $3, $4, $5) RETURNING id_usuario, nombre, correo`,
      [nombre, apellido_paterno, apellido_materno, correo, passwordHash]
    );

    res.status(201).json({
      message: 'Usuario registrado exitosamente',
      user: newUser.rows[0],
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error interno del servidor' });
  }
};

// Iniciar sesión
exports.login = async (req, res) => {
  const { correo, contrasena } = req.body;

  try {
    const result = await db.query('SELECT * FROM usuario WHERE correo = $1', [correo]);
    if (result.rows.length === 0) {
      return res.status(400).json({ message: 'Credenciales inválidas' });
    }

    const user = result.rows[0];

    // Verificar contraseña
    const validPassword = await bcrypt.compare(contrasena, user.contrasena);
    if (!validPassword) {
      return res.status(400).json({ message: 'Credenciales inválidas' });
    }

    // Generar Token JWT
    const token = jwt.sign(
      { id_usuario: user.id_usuario, apellido_paterno: user.apellido_paterno, apellido_materno: user.apellido_materno, correo: user.correo },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id_usuario: user.id_usuario,
        nombre: user.nombre,
        apellido_paterno: user.apellido_paterno,
        apellido_materno: user.apellido_materno,
        correo: user.correo,
        foto_perfil: user.foto_perfil,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error interno del servidor' });
  }
};

// Obtener información del perfil del usuario
exports.getProfile = async (req, res) => {
  try {
    const userResult = await db.query(
      `SELECT id_usuario, nombre, apellido_paterno, apellido_materno, correo, foto_perfil 
       FROM usuario 
       WHERE id_usuario = $1`,
      [req.user.id_usuario]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ message: 'Usuario no encontrado' });
    }

    const user = userResult.rows[0];

    const token = jwt.sign(
      { id_usuario: user.id_usuario, apellido_paterno: user.apellido_paterno, apellido_materno: user.apellido_materno, correo: user.correo },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({ user, token });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error al obtener datos del perfil' });
  }
};

// 1. Actualizar Nombre de Usuario
exports.updateProfile = async (req, res) => {
  const { nombre, apellido_paterno, apellido_materno } = req.body;
  const id_usuario = req.user.id_usuario;

  if (!nombre || !apellido_paterno) {
    return res.status(400).json({ message: 'Nombre y apellido paterno son obligatorios.' });
  }

  try {
    const result = await db.query(
      `UPDATE usuario 
       SET nombre = $1, apellido_paterno = $2, apellido_materno = $3 
       WHERE id_usuario = $4 
       RETURNING id_usuario, nombre, apellido_paterno, apellido_materno, correo, foto_perfil`,
      [nombre, apellido_paterno, apellido_materno || '', id_usuario]
    );

    res.json({
      message: 'Perfil actualizado correctamente',
      user: result.rows[0],
    });
  } catch (error) {
    console.error('Error al actualizar perfil:', error);
    res.status(500).json({ message: 'Error interno al actualizar perfil' });
  }
};

exports.updateProfilePhoto = async (req, res) => {
  const foto = Number(req.body.foto_perfil);
  if (!Number.isInteger(foto) || foto < 1 || foto > 10) {
    return res.status(400).json({ message: 'Foto de perfil inválida' });
  }
  try {
    const result = await db.query(
      `UPDATE usuario
       SET foto_perfil = $1
       WHERE id_usuario = $2
       RETURNING id_usuario, nombre, apellido_paterno, apellido_materno, correo, foto_perfil`,
      [foto, req.user.id_usuario]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Usuario no encontrado' });
    }
    res.json({ message: 'Foto de perfil actualizada', user: result.rows[0] });
  } catch (error) {
    console.error('Error al actualizar foto de perfil:', error);
    res.status(500).json({ message: 'Error al guardar la foto de perfil' });
  }
};

// 2. Cambiar Contraseña en la Base de Datos
exports.changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const id_usuario = req.user.id_usuario;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ message: 'Todos los campos son requeridos.' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ message: 'La nueva contraseña debe tener al menos 6 caracteres.' });
  }

  try {
    // Verificar contraseña actual
    const userQuery = await db.query('SELECT contrasena FROM usuario WHERE id_usuario = $1', [id_usuario]);
    if (userQuery.rows.length === 0) {
      return res.status(404).json({ message: 'Usuario no encontrado.' });
    }

    const validPassword = await bcrypt.compare(currentPassword, userQuery.rows[0].contrasena);
    if (!validPassword) {
      return res.status(400).json({ message: 'La contraseña actual es incorrecta.' });
    }

    // Encriptar y guardar nueva contraseña
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await db.query('UPDATE usuario SET contrasena = $1 WHERE id_usuario = $2', [hashedPassword, id_usuario]);

    res.json({ message: 'Contraseña modificada exitosamente' });
  } catch (error) {
    console.error('Error al cambiar contraseña:', error);
    res.status(500).json({ message: 'Error interno al cambiar la contraseña' });
  }
};


exports.getNotificationSettings = async (req, res) => {
  try {
    const r = await db.query('SELECT notif_correo FROM usuario WHERE id_usuario = $1', [req.user.id_usuario]);
    res.json({ notif_correo: r.rows[0]?.notif_correo ?? true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error al obtener preferencias' });
  }
};

exports.updateNotificationSettings = async (req, res) => {
  const { notif_correo } = req.body;
  if (typeof notif_correo !== 'boolean') {
    return res.status(400).json({ message: 'Valor inválido' });
  }
  try {
    await db.query('UPDATE usuario SET notif_correo = $1 WHERE id_usuario = $2', [notif_correo, req.user.id_usuario]);
    res.json({ message: 'Preferencia actualizada', notif_correo });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error al guardar preferencia' });
  }
};

const CODIGO_MINUTOS = 15;
const CODIGO_INTENTOS = 5;
 
const buscarCodigoVigente = async (correo) => {
  const r = await db.query(
    `SELECT r.id_recuperacion, r.id_usuario, r.codigo_hash, r.intentos
     FROM recuperacion_contrasena r
     JOIN usuario u ON u.id_usuario = r.id_usuario
     WHERE LOWER(u.correo) = LOWER($1) AND r.usado = FALSE AND r.expira > NOW()
     ORDER BY r.fecha_creacion DESC
     LIMIT 1`,
    [correo]
  );
  return r.rows[0];
};
 
const validarCodigo = async (correo, codigo) => {
  const registro = await buscarCodigoVigente(correo);
  if (!registro) {
    return { ok: false, message: 'El código expiró o no es válido. Solicita uno nuevo.' };
  }
  if (registro.intentos >= CODIGO_INTENTOS) {
    return { ok: false, message: 'Demasiados intentos. Solicita un código nuevo.' };
  }
  const coincide = await bcrypt.compare(String(codigo), registro.codigo_hash);
  if (!coincide) {
    await db.query(
      'UPDATE recuperacion_contrasena SET intentos = intentos + 1 WHERE id_recuperacion = $1',
      [registro.id_recuperacion]
    );
    const restantes = CODIGO_INTENTOS - registro.intentos - 1;
    return {
      ok: false,
      message: restantes > 0
        ? `Código incorrecto. Te quedan ${restantes} intentos.`
        : 'Demasiados intentos. Solicita un código nuevo.',
    };
  }
  return { ok: true, registro };
};
 
exports.forgotPassword = async (req, res) => {
  const correo = String(req.body.correo || '').trim();
  const respuesta = { message: 'Si el correo está registrado, te enviamos un código de verificación.' };
 
  if (!correo) {
    return res.status(400).json({ message: 'Ingresa tu correo electrónico.' });
  }
 
  try {
    const u = await db.query(
      'SELECT id_usuario, nombre, correo FROM usuario WHERE LOWER(correo) = LOWER($1)',
      [correo]
    );
    if (u.rows.length === 0) {
      return res.json(respuesta);
    }
    const user = u.rows[0];
 
    const codigo = crypto.randomInt(100000, 1000000).toString();
    const codigoHash = await bcrypt.hash(codigo, 10);
 
    await db.query(
      'DELETE FROM recuperacion_contrasena WHERE id_usuario = $1',
      [user.id_usuario]
    );
    await db.query(
      `INSERT INTO recuperacion_contrasena (id_usuario, codigo_hash, expira)
       VALUES ($1, $2, NOW() + make_interval(mins => $3))`,
      [user.id_usuario, codigoHash, CODIGO_MINUTOS]
    );
 
    const html = `
    <div style="background:#F8FAFC;padding:24px;font-family:Arial,Helvetica,sans-serif">
      <div style="max-width:480px;margin:auto;background:#fff;border-radius:16px;padding:28px;text-align:center">
        <div style="color:#1D61E7;font-weight:bold;font-size:18px">U-Learn</div>
        <h2 style="color:#1E293B;margin:16px 0 8px">Recupera tu contraseña</h2>
        <p style="color:#475569;font-size:14px">Hola ${String(user.nombre).replace(/[<>&"']/g, '')}, usa este código para restablecer tu contraseña:</p>
        <div style="font-size:34px;font-weight:bold;letter-spacing:8px;color:#1D61E7;background:#F1F5F9;border-radius:12px;padding:16px;margin:20px 0">${codigo}</div>
        <p style="color:#64748B;font-size:13px">El código vence en ${CODIGO_MINUTOS} minutos.</p>
        <p style="color:#94A3B8;font-size:12px;margin-top:24px">Si no solicitaste este cambio, ignora este correo. Tu contraseña no se modificará.</p>
      </div>
    </div>`;
 
    await sendMail(user.correo, 'Tu código para recuperar la contraseña', html);
    res.json(respuesta);
  } catch (error) {
    console.error('Error en recuperación de contraseña:', error);
    res.status(500).json({ message: 'No se pudo enviar el código. Intenta más tarde.' });
  }
};
 
exports.verifyResetCode = async (req, res) => {
  const correo = String(req.body.correo || '').trim();
  const codigo = String(req.body.codigo || '').trim();
 
  if (!correo || !/^\d{6}$/.test(codigo)) {
    return res.status(400).json({ message: 'Ingresa el código de 6 dígitos.' });
  }
 
  try {
    const v = await validarCodigo(correo, codigo);
    if (!v.ok) {
      return res.status(400).json({ message: v.message });
    }
    res.json({ message: 'Código verificado' });
  } catch (error) {
    console.error('Error al verificar código:', error);
    res.status(500).json({ message: 'Error interno del servidor' });
  }
};
 
exports.resetPassword = async (req, res) => {
  const correo = String(req.body.correo || '').trim();
  const codigo = String(req.body.codigo || '').trim();
  const nuevaContrasena = String(req.body.nuevaContrasena || '');
 
  if (!correo || !/^\d{6}$/.test(codigo)) {
    return res.status(400).json({ message: 'Datos incompletos.' });
  }
  if (nuevaContrasena.length < 6) {
    return res.status(400).json({ message: 'La contraseña debe tener al menos 6 caracteres.' });
  }
 
  try {
    const v = await validarCodigo(correo, codigo);
    if (!v.ok) {
      return res.status(400).json({ message: v.message });
    }
 
    const hash = await bcrypt.hash(nuevaContrasena, 10);
    await db.query('UPDATE usuario SET contrasena = $1 WHERE id_usuario = $2', [hash, v.registro.id_usuario]);
    await db.query('DELETE FROM recuperacion_contrasena WHERE id_usuario = $1', [v.registro.id_usuario]);
 
    res.json({ message: 'Contraseña actualizada. Ya puedes iniciar sesión.' });
  } catch (error) {
    console.error('Error al restablecer contraseña:', error);
    res.status(500).json({ message: 'Error interno del servidor' });
  }
};