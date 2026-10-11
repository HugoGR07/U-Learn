require('./jobs/weeklySummary');
const express = require('express');
const cors = require('cors');
require('dotenv').config();

// 1. Importar los archivos de rutas
const authRoutes = require('./routes/authRoutes');
const examRoutes = require('./routes/examRoutes');
const guideRoutes = require('./routes/guideRoutes');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Ruta de prueba
app.get('/', (req, res) => {
  res.json({ mensaje: '¡Servidor Backend de U-Learn funcionando correctamente!' });
});

// 2. Registrar las rutas principales
app.use('/api/auth', authRoutes);
app.use('/api/exam', examRoutes);
app.use('/api/guides', guideRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor ejecutándose en: http://localhost:${PORT}`);
});