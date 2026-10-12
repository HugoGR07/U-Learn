import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'lesson_view.dart';
import 'exam_view.dart'; // Asegúrate de importar tu vista de examen

class StudyView extends StatefulWidget {
  final int idGuia;

  const StudyView({
    super.key,
    required this.idGuia,
  });

  @override
  State<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends State<StudyView> {
  bool _isLoading = true;
  Map<String, dynamic>? _guia;
  List<dynamic> _secciones = [];

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getGuideDetails(widget.idGuia);

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _guia = res['data']?['guia'] as Map<String, dynamic>?;
          _secciones = List<dynamic>.from(res['data']?['secciones'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Error al cargar el curso'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  // Prepara la lista plana de lecciones para navegación
  List<Map<String, dynamic>> _getAllLessonsFlat() {
    final List<Map<String, dynamic>> allLessons = [];
    for (var sec in _secciones) {
      final contenidos = sec['contenidos'] as List<dynamic>? ?? [];
      for (var cont in contenidos) {
        allLessons.add({
          'id_seccion': sec['id_seccion'],
          'titulo_seccion': sec['titulo'],
          'titulo_contenido': cont['titulo'],
          'contenido': cont['contenido'],
        });
      }
    }
    return allLessons;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1D61E7)),
        ),
      );
    }

    final String title = _guia?['nombre_tema'] ?? 'Guía de estudio';
    final String description =
        _guia?['descripcion'] ?? 'Aprende los conceptos clave paso a paso.';
    final flatLessons = _getAllLessonsFlat();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // 1. Barra Superior
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1E293B),
                      size: 20,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Text(
                    'Tu guía de estudio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.home_outlined,
                      color: Color(0xFF1D61E7),
                      size: 24,
                    ),
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Tarjeta Informativa del Curso
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Color(0xFF1D61E7),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'Secciones: ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '${_secciones.length} módulos',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Objetivo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D61E7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Renderizado de Secciones, Lecciones y Examen Final de Sección
              ..._secciones.asMap().entries.map((entry) {
                final int sectionIndex = entry.key;
                final sec = entry.value;
                final contenidos = sec['contenidos'] as List<dynamic>? ?? [];
                final examen = sec['examen'] as Map<String, dynamic>?;
                final bool isSectionCompleted = sec['completado'] == true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado de la Sección
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Sección ${sectionIndex + 1}: ${sec['titulo'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${contenidos.length} lecciones',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D61E7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de Lecciones de la Sección
                    ...contenidos.asMap().entries.map((cEntry) {
                      final int cIndex = cEntry.key;
                      final cont = cEntry.value;

                      final globalIndex = flatLessons.indexWhere(
                        (item) =>
                            item['id_seccion'] == sec['id_seccion'] &&
                            item['titulo_contenido'] == cont['titulo'],
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildLessonItem(
                          title: cont['titulo'] ?? 'Lección ${cIndex + 1}',
                          isCompleted: isSectionCompleted,
                          lessonNumber: cIndex + 1,
                          onTap: () async {
                            final refresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LessonView(
                                  idSeccion: sec['id_seccion'],
                                  allLessons: flatLessons,
                                  currentIndex:
                                      globalIndex >= 0 ? globalIndex : 0,
                                ),
                              ),
                            );

                            if (refresh == true && mounted) {
                              _fetchCourseDetails();
                            }
                          },
                        ),
                      );
                    }).toList(),

                    // Tarjeta del Examen al final de la Sección
                    if (examen != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildExamItem(
                          examen: examen,
                          isUnlocked: isSectionCompleted,
                          onTap: () async {
                          if (!isSectionCompleted) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de advertencia llamativo
              const Icon(
                Icons.lock_clock_rounded,
                color: Color(0xFFF59E0B),
                size: 48,
              ),
              const SizedBox(height: 16),
              
              // Título de la alerta
              const Text(
                'Sección bloqueada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),

              // Tu mensaje exacto
              const Text(
                'Debes completar todas las lecciones de esta sección para desbloquear el examen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Continuar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return;
  }

                            // Navegación a la vista del examen
                            final refresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExamView(
                                  examen: examen,
                                  idSeccion: sec['id_seccion'],
                                ),
                              ),
                            );

                            if (refresh == true && mounted) {
                              _fetchCourseDetails();
                            }
                          },
                        ),
                      ),

                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para renderizar cada Lección
  Widget _buildLessonItem({
    required String title,
    bool isCompleted = false,
    int? lessonNumber,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        )
                      : Text(
                          '$lessonNumber',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D61E7),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para renderizar la tarjeta del Examen al final de la Sección
  Widget _buildExamItem({
    required Map<String, dynamic> examen,
    required bool isUnlocked,
    required VoidCallback onTap,
  }) {
    final int totalPreguntas = (examen['preguntas'] as List?)?.length ?? 0;
    final int duracion = examen['tiempo_duracion_minutos'] ?? 15;

    return Material(
      color: isUnlocked ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnlocked ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: Icon(
                    isUnlocked ? Icons.assignment_outlined : Icons.lock_rounded,
                    color: isUnlocked ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examen Evaluativo de la Sección',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? const Color(0xFF312E81) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlocked
                          ? '$totalPreguntas preguntas • $duracion min'
                          : 'Completa las lecciones para desbloquear',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUnlocked ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isUnlocked ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}