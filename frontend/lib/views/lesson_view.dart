import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LessonView extends StatefulWidget {
  final int idSeccion;
  final List<Map<String, dynamic>> allLessons;
  final int currentIndex;

  const LessonView({
    super.key,
    required this.idSeccion,
    required this.allLessons,
    required this.currentIndex,
  });

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
    _markCurrentSectionCompleted();
  }

  void _markCurrentSectionCompleted() async {
    final currentLesson = widget.allLessons[_index];
    final idSeccion = currentLesson['id_seccion'];
    if (idSeccion != null) {
      await ApiService.completeSection(idSeccion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLesson = widget.allLessons[_index];
    final totalLessons = widget.allLessons.length;
    final progressValue = (_index + 1) / totalLessons;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 1. Barra Superior con Título
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF1E293B),
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ),
                        Text(
                          'Lección ${_index + 1} de $totalLessons',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 2. Barra de Progreso Superior
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1D61E7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3. Título de la Lección
                    Text(
                      currentLesson['titulo_contenido'] ?? 'Título de Lección',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contenido / Texto Generado por Gemini
                    Text(
                      currentLesson['contenido'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 4. Tarjeta Explicativa de Apoyo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF2FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF1D61E7), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Punto clave',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D61E7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'RecuerdaRepasar este concepto para ponerlo en práctica en tu vida financiera cotidiana.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 5. Botones Inferiores (Anterior / Siguiente)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  // Botón Anterior
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _index > 0
                          ? () {
                              setState(() {
                                _index--;
                              });
                              _markCurrentSectionCompleted();
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(
                          color: _index > 0 ? const Color(0xFF1D61E7) : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Anterior',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _index > 0 ? const Color(0xFF1D61E7) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Botón Siguiente
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_index < totalLessons - 1) {
                          setState(() {
                            _index++;
                          });
                          _markCurrentSectionCompleted();
                        } else {
                          // Al finalizar la última lección, regresa al resumen del curso
                          Navigator.pop(context, true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF1D61E7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _index < totalLessons - 1 ? 'Siguiente' : 'Finalizar',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}