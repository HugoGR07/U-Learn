const express = require('express');
const router = express.Router();
const examController = require('../controllers/examController');
const authMiddleware = require('../middlewares/authMiddleware');

// Obtener preguntas del examen
router.get('/:examId/questions', authMiddleware, examController.getExamQuestions);
// Ruta para el chat del Tutor de IA basado en resultados del examen
router.post('/tutor-ia', authMiddleware, examController.askAiTutor);

// Enviar respuestas y calificar
router.post('/:examId/submit', authMiddleware, examController.submitExam);

module.exports = router;