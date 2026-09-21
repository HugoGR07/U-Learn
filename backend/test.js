require('dotenv').config();
const { GoogleGenAI } = require('@google/genai');

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

async function checkModels() {
  try {
    console.log("Probando conexión con API Key:", process.env.GEMINI_API_KEY ? "Detectada" : "NO DETECTADA");
    const response = await ai.models.list();
    console.log("\n--- MODELOS DISPONIBLES EN TU CUENTA ---");
    for await (const model of response) {
      console.log(`- ${model.name}`);
    }
  } catch (error) {
    console.error("Error al consultar la API:", error);
  }
}

checkModels();