const express = require('express');
const router = express.Router();
const examController = require('../controllers/examController');
const authMiddleware = require('../middlewares/authMiddleware');
const { tutorLimiter } = require('../middlewares/limits');

// Ruta para la interacción con el tutor de IA
router.post('/tutor-ia', authMiddleware, tutorLimiter, examController.askAiTutor);

// Obtener preguntas del examen
router.get('/:examId/questions', authMiddleware, examController.getExamQuestions);

// Enviar respuestas y calificar
router.post('/:examId/submit', authMiddleware, examController.submitExam);

router.get('/:examId/last-attempt', authMiddleware, examController.getLastAttempt);

module.exports = router;