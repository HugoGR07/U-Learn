import 'package:flutter/material.dart';

class ResultView extends StatelessWidget {
  final int totalPreguntas;
  final int correctas;
  final int incorrectas;
  final int porcentaje;

  const ResultView({
    super.key,
    required this.totalPreguntas,
    required this.correctas,
    required this.incorrectas,
    required this.porcentaje,
  });

  /// Constructor factory para instanciar ResultView directamente desde el mapa de la API
  factory ResultView.fromMap(Map<String, dynamic> rawData) {
    // Si la respuesta viene envuelta en un objeto 'resultado', usamos ese submapa
    final Map<String, dynamic> data =
        (rawData['resultado'] is Map<String, dynamic>)
            ? rawData['resultado']
            : rawData;

    final int total =
        int.tryParse(data['total_preguntas']?.toString() ?? '') ??
        int.tryParse(data['total']?.toString() ?? '') ??
        0;

    final int aciertos =
        int.tryParse(data['aciertos']?.toString() ?? '') ??
        int.tryParse(data['respuestas_correctas']?.toString() ?? '') ??
        0;

    final int desaciertos =
        int.tryParse(data['incorrectas']?.toString() ?? '') ??
        int.tryParse(data['respuestas_incorrectas']?.toString() ?? '') ??
        (total > aciertos ? total - aciertos : 0);

    // Parseo seguro de la calificación o porcentaje
    num rawCalificacion =
        data['porcentaje'] ?? data['calificacion'] ?? data['promedio'] ?? 0;

    int pct = rawCalificacion.round();
    // Si la calificación viene en escala 0-10 (ej. 8.5), la escalamos a porcentaje (85%)
    if (rawCalificacion > 0 && rawCalificacion <= 10) {
      pct = (rawCalificacion * 10).round();
    }

    return ResultView(
      totalPreguntas: total,
      correctas: aciertos,
      incorrectas: desaciertos,
      porcentaje: pct,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 1. Destellos superiores
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 24),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Icono de Trofeo / Medalla según puntaje
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      porcentaje >= 60
                          ? Icons.emoji_events_rounded
                          : Icons.stars_rounded,
                      size: 80,
                      color: porcentaje >= 60
                          ? const Color(0xFFEAB308)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Título y Subtítulo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      porcentaje >= 60 ? '¡Felicidades!' : '¡Buen intento!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      porcentaje >= 60 ? '🎉' : '💪',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                const Text(
                  'Has completado la evaluación de la sección',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Calificación Promedio Dinámica
                const Text(
                  'Tu calificación',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$porcentaje%',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D61E7),
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$correctas de $totalPreguntas correctas',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 36),

                // 5. Tarjetas de Estadísticas Dinámicas
                Row(
                  children: [
                    // Correctas
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$correctas',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Respuestas correctas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Incorrectas
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$incorrectas',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Respuestas incorrectas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF991B1B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // 6. Botón "Ver plan de estudio"
                ElevatedButton(
                  onPressed: () {
                    // Devuelve `true` a study_view para refrescar el progreso
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: const Color(0xFF1D61E7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Ver plan de estudio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 7. Botón "Volver a mis cursos"
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: Color(0xFF1D61E7), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Volver a mis cursos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D61E7),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}