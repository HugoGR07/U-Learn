import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class LessonView extends StatefulWidget {
  final int idSeccion;
  final int numeroSeccion;
  final String tituloSeccion;
  final List<Map<String, dynamic>> lessons;
  final int currentIndex;
  final bool tieneExamen;

  const LessonView({
    super.key,
    required this.idSeccion,
    required this.numeroSeccion,
    required this.tituloSeccion,
    required this.lessons,
    required this.currentIndex,
    this.tieneExamen = true,
  });

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  static const Color _primary = Color(0xFF1D61E7);
  static const Color _text = Color(0xFF1E293B);
  static const Color _body = Color(0xFF475569);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  late int _index;
  bool _busy = false;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final int maxIndex = widget.lessons.length - 1;
    _index = widget.currentIndex < 0
        ? 0
        : (widget.currentIndex > maxIndex ? maxIndex : widget.currentIndex);
    ApiService.startSection(widget.idSeccion);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _parseContenido(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String) return null;
    final texto = raw.trim();
    if (!texto.startsWith('{')) return null;
    try {
      final data = jsonDecode(texto);
      if (data is Map && data['introduccion'] != null) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return null;
  }

  void _goTo(int index) {
    setState(() => _index = index);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finishSection() async {
    setState(() => _busy = true);
    final ok = await ApiService.completeSection(widget.idSeccion);
    if (!mounted) return;
    if (ok) {
      NotificationService.showProgress(
        '¡Sección completada! ✅',
        widget.tieneExamen
            ? 'Ya puedes presentar el examen de la sección ${widget.numeroSeccion}.'
            : 'Sigue así, vas avanzando en tu guía.',
      );
      NotificationService.refreshReminder();
      Navigator.pop(context, widget.tieneExamen ? 'examen' : true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo registrar tu avance. Intenta de nuevo.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLesson = widget.lessons[_index];
    final totalLessons = widget.lessons.length;
    final bool isLast = _index == totalLessons - 1;
    final estructura = _parseContenido(currentLesson['contenido']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 24, 0),
              child: Column(
                children: [
                  // 1. Barra Superior con Título
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _text,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sección ${widget.numeroSeccion}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            Text(
                              widget.tituloSeccion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_index + 1}/$totalLessons',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Barra de Progreso Superior
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: List.generate(totalLessons, (i) {
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 6,
                            margin: EdgeInsets.only(right: i == totalLessons - 1 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: i <= _index ? _primary : _border,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(_index),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'TEMA ${_index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 3. Título de la Lección
                      Text(
                        currentLesson['titulo'] ?? 'Título de Lección',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _text,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (estructura != null)
                        ..._buildStructured(estructura)
                      else
                        ..._buildPlain(currentLesson['contenido']?.toString() ?? ''),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Botones Inferiores (Anterior / Siguiente)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _index > 0 && !_busy ? () => _goTo(_index - 1) : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(
                          color: _index > 0 ? _primary : const Color(0xFFCBD5E1),
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
                          color: _index > 0 ? _primary : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (isLast) {
                                _finishSection();
                              } else {
                                _goTo(_index + 1);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: isLast ? const Color(0xFF4F46E5) : _primary,
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isLast
                                  ? (widget.tieneExamen ? 'Ir al examen' : 'Finalizar')
                                  : 'Siguiente',
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

  List<Widget> _buildStructured(Map<String, dynamic> data) {
    final String introduccion = data['introduccion']?.toString() ?? '';
    final List<dynamic> conceptos = (data['conceptos'] as List?) ?? [];
    final String ejemplo = data['ejemplo']?.toString() ?? '';
    final String consejo = data['consejo']?.toString() ?? '';
    final String resumen = data['resumen']?.toString() ?? '';

    return [
      Text(
        introduccion,
        style: const TextStyle(fontSize: 15, color: _body, height: 1.6),
      ),
      if (conceptos.isNotEmpty) ...[
        const SizedBox(height: 28),
        _sectionLabel(Icons.auto_awesome_rounded, 'Conceptos clave'),
        const SizedBox(height: 12),
        ...conceptos.asMap().entries.map((e) {
          final c = e.value is Map ? e.value as Map : const {};
          return _conceptCard(
            e.key + 1,
            c['titulo']?.toString() ?? '',
            c['explicacion']?.toString() ?? '',
            isLast: e.key == conceptos.length - 1,
          );
        }),
      ],
      if (ejemplo.isNotEmpty) ...[
        const SizedBox(height: 20),
        _calloutCard(
          icon: Icons.calculate_rounded,
          title: 'Ejemplo práctico',
          text: ejemplo,
          background: const Color(0xFFECFDF5),
          accent: const Color(0xFF059669),
        ),
      ],
      if (consejo.isNotEmpty) ...[
        const SizedBox(height: 14),
        _calloutCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Consejo',
          text: consejo,
          background: const Color(0xFFFFFBEB),
          accent: const Color(0xFFD97706),
        ),
      ],
      if (resumen.isNotEmpty) ...[
        const SizedBox(height: 14),
        _calloutCard(
          icon: Icons.bookmark_rounded,
          title: 'En resumen',
          text: resumen,
          background: const Color(0xFFEBF2FE),
          accent: _primary,
        ),
      ],
    ];
  }

  List<Widget> _buildPlain(String contenido) {
    return [
      // Contenido / Texto Generado por Gemini
      Text(
        contenido,
        style: const TextStyle(fontSize: 15, color: _body, height: 1.5),
      ),
      const SizedBox(height: 28),

      // 4. Tarjeta Explicativa de Apoyo
      _calloutCard(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Punto clave',
        text: 'Recuerda repasar este concepto para ponerlo en práctica en tu vida financiera cotidiana.',
        background: const Color(0xFFEBF2FE),
        accent: _primary,
      ),
    ];
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
      ],
    );
  }

  Widget _conceptCard(int number, String title, String text, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFC7D7FB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(fontSize: 13.5, color: _body, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calloutCard({
    required IconData icon,
    required String title,
    required String text,
    required Color background,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}