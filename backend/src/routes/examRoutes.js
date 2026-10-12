const express = require('express');
const router = express.Router();
const examController = require('../controllers/examController');
const authMiddleware = require('../middlewares/authMiddleware');

// Ruta para la interacción con el tutor de IA
router.post('/tutor-ia', authMiddleware, examController.askAiTutor);

// Obtener preguntas del examen
router.get('/:examId/questions', authMiddleware, examController.getExamQuestions);

// Enviar respuestas y calificar
router.post('/:examId/submit', authMiddleware, examController.submitExam);

module.exports = router;