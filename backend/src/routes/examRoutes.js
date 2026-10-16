const express = require('express');
const router = express.Router();
const examController = require('../controllers/examController');
const authMiddleware = require('../middlewares/authMiddleware');
const { tutorLimiter } = require('../middlewares/limits');

<<<<<<< HEAD
// Ruta para la interacción con el tutor de IA
router.post('/tutor-ia', authMiddleware, examController.askAiTutor);

=======
router.post('/tutor-ia', authMiddleware, tutorLimiter, examController.askAiTutor);
>>>>>>> carlos_rama_2
// Obtener preguntas del examen
router.get('/:examId/questions', authMiddleware, examController.getExamQuestions);

// Enviar respuestas y calificar
router.post('/:examId/submit', authMiddleware, examController.submitExam);

module.exports = router;