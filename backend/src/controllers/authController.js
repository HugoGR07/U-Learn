const db = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
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
      `SELECT id_usuario, nombre, apellido_paterno, apellido_materno, correo 
       FROM usuario 
       WHERE id_usuario = $1`,
      [req.user.id_usuario]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ message: 'Usuario no encontrado' });
    }

    res.json({ user: userResult.rows[0] });
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
       RETURNING id_usuario, nombre, apellido_paterno, apellido_materno, correo`,
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

exports.testEmail = async (req, res) => {
  try {
    await sendMail(req.user.correo, 'Prueba de correo U-Learn', '<p>Si ves esto, el correo funciona ✅</p>');
    res.json({ message: 'Correo enviado' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'No se pudo enviar el correo' });
  }
};