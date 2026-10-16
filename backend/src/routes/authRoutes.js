const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middlewares/authMiddleware');
const { authLimiter } = require('../middlewares/limits');

// Registro de usuario
router.post('/register', authLimiter, authController.register);

// Inicio de sesión
router.post('/login', authLimiter, authController.login);

// Perfil de usuario (requiere token JWT)
router.get('/me', authMiddleware, authController.getProfile);

router.put('/update-profile', authMiddleware, authController.updateProfile);
router.put('/change-password', authMiddleware, authController.changePassword);

router.get('/notification-settings', authMiddleware, authController.getNotificationSettings);
router.put('/notification-settings', authMiddleware, authController.updateNotificationSettings);
router.post('/test-email', authMiddleware, authController.testEmail);


module.exports = router;