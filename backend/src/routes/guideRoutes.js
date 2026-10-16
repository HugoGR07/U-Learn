const express = require('express');
const router = express.Router();
const guideController = require('../controllers/guideController');
const authMiddleware = require('../middlewares/authMiddleware');
const { guideDailyLimit } = require('../middlewares/limits');

// Ruta para obtener la lista de temas desde la BD
router.get('/topics', authMiddleware, guideController.getTopics);

// Generar una nueva guía con OpenAI y guardarla en la BD
router.post('/generate', authMiddleware, guideDailyLimit, guideController.generateCourse);

// Obtener la lista de guías del usuario
router.get('/my-guides', authMiddleware, guideController.getUserGuides);

router.get('/my-guides', authMiddleware, guideController.getUserGuides);

router.get('/details/:id_guia', authMiddleware, guideController.getGuideDetails);
router.post('/complete-section', authMiddleware, guideController.completeSection);

router.post('/start-section', authMiddleware, guideController.startSection);

module.exports = router;