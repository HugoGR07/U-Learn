import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'lesson_view.dart';
import 'exam_view.dart';
import '../widgets/encabezado_azul.dart';

class StudyView extends StatefulWidget {
  final int idGuia;

  const StudyView({
    super.key,
    required this.idGuia,
  });

  @override
  State<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends State<StudyView>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1D61E7);
  static const Color _text = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF10B981);
  static const Color _exam = Color(0xFF4F46E5);

  bool _isLoading = true;
  Map<String, dynamic>? _guia;
  List<dynamic> _secciones = [];
  final Set<int> _expanded = {};
  bool _expandedInit = false;

  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _fetchCourseDetails();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  int get _currentSectionIndex =>
      _secciones.indexWhere((s) => s['completado'] != true);

  Widget _shimmer() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, _) {
          final t = (_floatController.value * 1.6).clamp(0.0, 1.0);
          return FractionalTranslation(
            translation: Offset(-1 + t * 2, 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.3, 0.5, 0.7],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pulseHalo(Widget child) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final v = (_floatController.value * 2) % 1.0;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + v * 0.4,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _primary.withValues(alpha: (1 - v) * 0.45),
                    width: 2,
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: child,
    );
  }

  Widget _decorCircle(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primary.withValues(alpha: alpha),
      ),
    );
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
          if (!_expandedInit) {
            _expandedInit = true;
            final next = _secciones.indexWhere((s) => s['completado'] != true);
            _expanded.add(next >= 0 ? next : 0);
          }
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

  List<Map<String, dynamic>> _lessonsOf(Map<String, dynamic> sec) {
    final contenidos = sec['contenidos'] as List<dynamic>? ?? [];
    return contenidos
        .map((c) => {
              'titulo': c['titulo'],
              'contenido': c['contenido'],
            })
        .toList();
  }

  Future<void> _openLesson(Map<String, dynamic> sec, int sectionIndex, int lessonIndex) async {
    final lessons = _lessonsOf(sec);
    if (lessons.isEmpty) return;
    final examen = sec['examen'] as Map<String, dynamic>?;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonView(
          idSeccion: sec['id_seccion'],
          numeroSeccion: sectionIndex + 1,
          tituloSeccion: sec['titulo'] ?? '',
          lessons: lessons,
          currentIndex: lessonIndex,
          tieneExamen: examen != null,
        ),
      ),
    );

    if (!mounted) return;
    if (result == 'examen' && examen != null) {
      await _fetchCourseDetails();
      if (!mounted) return;
      await _openExam(sec, sectionIndex, examen);
    } else if (result != null) {
      _fetchCourseDetails();
    }
  }

  Future<void> _openExam(Map<String, dynamic> sec, int sectionIndex, Map<String, dynamic> examen) async {
    // Navegación a la vista del examen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamView(
          examen: {...examen, 'titulo': 'Examen · Sección ${sectionIndex + 1}'},
          idSeccion: sec['id_seccion'],
        ),
      ),
    );

    if (mounted) _fetchCourseDetails();
  }

  void _showLockedDialog() {
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
                  color: _text,
                ),
              ),
              const SizedBox(height: 10),

              // Mensaje exacto
              const Text(
                'Debes completar todas las lecciones de esta sección para desbloquear el examen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _muted,
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
                    backgroundColor: _primary,
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _secciones.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    final String title = _guia?['nombre_tema'] ?? 'Guía de estudio';
    final String description =
        _guia?['descripcion'] ?? 'Aprende los conceptos clave paso a paso.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _fetchCourseDetails,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // 1. Encabezado azul (se desplaza junto con el contenido)
                EncabezadoAzul(
                  title: 'Tu guía de estudio',
                  grande: true,
                  leading: EncabezadoAzul.boton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    grande: true,
                    size: 22,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  trailing: EncabezadoAzul.boton(
                    icon: Icons.home_outlined,
                    grande: true,
                    size: 25,
                    onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // 2. Tarjeta Informativa del Curso
                      Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF2FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            Positioned(top: -30, right: -20, child: _decorCircle(110, 0.07)),
                            Positioned(bottom: -40, right: 50, child: _decorCircle(80, 0.05)),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedBuilder(
                                    animation: _floatController,
                                    builder: (context, child) {
                                      final a = _floatController.value * 2 * math.pi;
                                      return Transform.translate(
                                        offset: Offset(0, math.sin(a) * 2.5),
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _primary.withValues(alpha: 0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: _primary,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _text,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF334155),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'Ruta de aprendizaje',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Estudia los temas de cada sección y presenta su examen.',
                        style: TextStyle(fontSize: 13, color: _muted),
                      ),
                      const SizedBox(height: 16),

                      // 3. Renderizado de Secciones, Lecciones y Examen Final de Sección
                      ..._secciones.asMap().entries.map((entry) {
                        return _buildSectionCard(
                          Map<String, dynamic>.from(entry.value as Map),
                          entry.key,
                        );
                      }),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> sec, int sectionIndex) {
    final contenidos = sec['contenidos'] as List<dynamic>? ?? [];
    final examen = sec['examen'] as Map<String, dynamic>?;
    final bool isSectionCompleted = sec['completado'] == true;
    final bool isExpanded = _expanded.contains(sectionIndex);
    final Color accent = isSectionCompleted ? _success : _primary;
    final bool isCurrent = sectionIndex == _currentSectionIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSectionCompleted ? const Color(0xFFF0FDF7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? accent.withValues(alpha: 0.35) : _border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isExpanded ? 0.05 : 0.02),
            blurRadius: isExpanded ? 14 : 8,
            offset: Offset(0, isExpanded ? 6 : 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() {
              if (isExpanded) {
                _expanded.remove(sectionIndex);
              } else {
                _expanded.add(sectionIndex);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _maybeHalo(
                    isCurrent,
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isExpanded && !isSectionCompleted
                            ? _primary
                            : accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: isSectionCompleted
                            ? const Icon(Icons.check_rounded, color: _success, size: 24)
                            : Text(
                                '${sectionIndex + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isExpanded ? Colors.white : _primary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SECCIÓN ${sectionIndex + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sec['titulo'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: _text,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !isExpanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(height: 1, color: _border),
                          const SizedBox(height: 12),
                          ...contenidos.asMap().entries.map((cEntry) {
                            final int cIndex = cEntry.key;
                            final cont = cEntry.value;
                            return _buildLessonItem(
                              title: cont['titulo'] ?? 'Tema ${cIndex + 1}',
                              isCompleted: isSectionCompleted,
                              lessonNumber: cIndex + 1,
                              showConnector: cIndex < contenidos.length - 1 || examen != null,
                              onTap: () => _openLesson(sec, sectionIndex, cIndex),
                            );
                          }),
                          // Tarjeta del Examen al final de la Sección
                          if (examen != null)
                            _buildExamItem(
                              examen: examen,
                              isUnlocked: isSectionCompleted,
                              onTap: () {
                                if (!isSectionCompleted) {
                                  _showLockedDialog();
                                  return;
                                }
                                _openExam(sec, sectionIndex, examen);
                              },
                            ),
                          if (!isSectionCompleted && contenidos.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _PressScale(
                              onTap: () => _openLesson(sec, sectionIndex, 0),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: _primary,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: _shimmer()),
                                    const Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            'Comenzar sección',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _maybeHalo(bool active, Widget child) => active ? _pulseHalo(child) : child;

  // Widget para renderizar cada Lección
  Widget _buildLessonItem({
    required String title,
    bool isCompleted = false,
    int? lessonNumber,
    bool showConnector = true,
    required VoidCallback onTap,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? _success : Colors.white,
                    border: Border.all(
                      color: isCompleted ? _success : _primary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                        : Text(
                            '$lessonNumber',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? _success.withValues(alpha: 0.4)
                          : const Color(0xFFC7D7FB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PressScale(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _text,
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
            ),
          ),
        ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: isUnlocked
                  ? AnimatedBuilder(
                      animation: _floatController,
                      builder: (context, child) => Transform.scale(
                        scale: 1 + math.sin(_floatController.value * 2 * math.pi) * 0.12,
                        child: child,
                      ),
                      child: const Icon(Icons.flag_rounded, color: _exam, size: 22),
                    )
                  : const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 22),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PressScale(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isUnlocked ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUnlocked ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examen de la sección',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? const Color(0xFF312E81) : _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isUnlocked
                              ? '$totalPreguntas preguntas'
                              : 'Completa los temas para desbloquear',
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
                    color: isUnlocked ? _exam : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}