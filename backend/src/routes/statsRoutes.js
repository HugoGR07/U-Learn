const express = require('express');
const router = express.Router();
const statsController = require('../controllers/statsController');
const authMiddleware = require('../middlewares/authMiddleware');

// Estadísticas generales del usuario para el dashboard
router.get('/dashboard', authMiddleware, statsController.getDashboard);

module.exports = router;
