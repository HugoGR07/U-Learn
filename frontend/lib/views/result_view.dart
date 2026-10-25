import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/efectos_animados.dart';
import 'fundamentos_view.dart';
import '../widgets/responsivo.dart';
import '../widgets/componentes_guia.dart';

class ResultView extends StatefulWidget {
  final int totalPreguntas;
  final int correctas;
  final int incorrectas;
  final int porcentaje;
  final List<Map<String, dynamic>> erroresDelExamen;
  final List<Map<String, dynamic>> examenCompleto;

  const ResultView({
    super.key,
    required this.totalPreguntas,
    required this.correctas,
    required this.incorrectas,
    required this.porcentaje,
    this.erroresDelExamen = const [],
    this.examenCompleto = const [],
  });

  /// Constructor factory para instanciar ResultView directamente desde el mapa de la API
  factory ResultView.fromMap(Map<String, dynamic> rawData) {
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

    num rawCalificacion =
        data['porcentaje'] ?? data['calificacion'] ?? data['promedio'] ?? 0;

    int pct = rawCalificacion.round();
    if (rawCalificacion > 0 && rawCalificacion <= 10) {
      pct = (rawCalificacion * 10).round();
    }

    List<Map<String, dynamic>> erroresList = [];
    if (rawData['errores'] is List) {
      erroresList = List<Map<String, dynamic>>.from(rawData['errores']);
    }

    List<Map<String, dynamic>> examenList = [];
    if (rawData['examen_completo'] is List) {
      examenList = List<Map<String, dynamic>>.from(rawData['examen_completo']);
    }

    return ResultView(
      totalPreguntas: total,
      correctas: aciertos,
      incorrectas: desaciertos,
      porcentaje: pct,
      erroresDelExamen: erroresList,
      examenCompleto: examenList,
    );
  }

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1D61E7);
  static const Color _text = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _warn = Color(0xFFF59E0B);
  static const Color _exam = Color(0xFF4F46E5);
  static const int _notaAprobatoria = 60;

  late final AnimationController _ambient;

  late final List<({int numero, String pregunta, bool correcta, String tuRespuesta, String respuestaCorrecta})> _items =
      _armarItems();
  late int _filtro = _items.any((i) => !i.correcta) ? 0 : 2;
  final Set<int> _reveladas = {};
  final Set<int> _repasadas = {};

  List<({int numero, String pregunta, bool correcta, String tuRespuesta, String respuestaCorrecta})> _armarItems() {
    final completo = widget.examenCompleto;
    if (completo.isNotEmpty && completo.every((e) => e.containsKey('es_correcta'))) {
      return [
        for (int i = 0; i < completo.length; i++)
          (
            numero: i + 1,
            pregunta: (completo[i]['pregunta'] ?? completo[i]['texto_pregunta'] ?? '').toString(),
            correcta: completo[i]['es_correcta'] == true,
            tuRespuesta: (completo[i]['respuesta_usuario'] ?? 'No respondida').toString(),
            respuestaCorrecta: (completo[i]['respuesta_correcta'] ?? '').toString(),
          ),
      ];
    }
    return [
      for (int i = 0; i < widget.erroresDelExamen.length; i++)
        (
          numero: i + 1,
          pregunta: (widget.erroresDelExamen[i]['pregunta'] ?? widget.erroresDelExamen[i]['texto_pregunta'] ?? '')
              .toString(),
          correcta: false,
          tuRespuesta: (widget.erroresDelExamen[i]['respuesta_usuario'] ?? 'No respondida').toString(),
          respuestaCorrecta: (widget.erroresDelExamen[i]['respuesta_correcta'] ?? '').toString(),
        ),
    ];
  }

  int get _totalErrores => _items.where((i) => !i.correcta).length;

  void _cambiarFiltro(int filtro) {
    if (_filtro == filtro) return;
    setState(() => _filtro = filtro);
  }

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  bool get _aprobado => widget.porcentaje >= _notaAprobatoria;

  Color get _colorNota {
    if (_aprobado) return _success;
    if (widget.porcentaje >= 40) return _warn;
    return _danger;
  }

  void _abrirFundamentos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FundamentosView(
          errores: widget.erroresDelExamen,
          examenCompleto: widget.examenCompleto,
        ),
      ),
    );
  }

  List<Widget> _destellos(double t) {
    return List.generate(3, (i) {
      final double a = t + i * 2 * math.pi / 3;
      final double s = 0.5 + 0.5 * math.sin(t * 3 + i * 1.7);
      return Transform.translate(
        offset: Offset(math.cos(a) * 100, math.sin(a) * 100),
        child: Opacity(
          opacity: (0.35 + 0.65 * s).clamp(0.0, 1.0),
          child: Icon(
            Icons.quiz,
            size: 12 + 8 * s,
            color: i.isEven ? const Color(0xFFF59E0B) : _primary,
          ),
        ),
      );
    });
  }

  Widget _buildHero() {
    final double meta = widget.porcentaje.clamp(0, 100).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: meta),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) {
                final double progreso = valor / 100;
                final double t = _ambient.value * 2 * math.pi;
                final double halo = 0.5 + 0.5 * math.sin(t * 2);
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 168 + halo * 12,
                      height: 168 + halo * 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorNota.withValues(alpha: 0.05 + halo * 0.05),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(170, 170),
                      painter: _AnilloPainter(
                        progreso: progreso,
                        color: _colorNota,
                        brillo: halo,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${valor.round()}%',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: _text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'calificación',
                          style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    ..._destellos(t),
                  ],
                );
              },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _colorNota.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _aprobado ? Icons.verified_rounded : Icons.trending_up_rounded,
                  size: 16,
                  color: _colorNota,
                ),
                const SizedBox(width: 6),
                Text(
                  _aprobado ? 'Aprobado' : 'Sigue practicando',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _colorNota,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _aprobado ? '¡Felicidades!' : '¡Buen intento!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _text),
          ),
          const SizedBox(height: 4),
          Text(
            'Acertaste ${widget.correctas} de ${widget.totalPreguntas} preguntas',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String valor,
    required String etiqueta,
    required Color color,
    required double fase,
    bool activo = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.01) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: activo ? color : _border, width: activo ? 1.8 : 1),
          boxShadow: activo
              ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 5))]
              : null,
        ),
        child: Column(
          children: [
            Flotante(
              amplitud: 2.5,
              fase: fase,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              valor,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _text),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _tituloSeccion(String titulo, {String? badge}) {
    return Row(
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _danger),
            ),
          ),
        ],
      ],
    );
  }

  Widget _zonaRevision() {
    final visibles = _items.where((i) => _filtro == 2 || (_filtro == 0 ? !i.correcta : i.correcta)).toList();
    final errores = _totalErrores;
    final repasadas = _repasadas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSeccion('Revisa tus respuestas'),
        const SizedBox(height: 4),
        const Text(
          'Intenta recordar la respuesta correcta antes de destaparla.',
          textAlign: TextAlign.justify,
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 14),
        _selectorFiltro(),
        if (_filtro != 1 && errores > 0) ...[
          const SizedBox(height: 14),
          _progresoRepaso(repasadas, errores),
        ],
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(_filtro),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: visibles.isEmpty
                ? [_vacioFiltro()]
                : [
                    for (int i = 0; i < visibles.length; i++)
                      Aparecer(
                        orden: i,
                        child: visibles[i].correcta ? _tarjetaAcierto(visibles[i]) : _tarjetaFallo(visibles[i]),
                      ),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _selectorFiltro() {
    final opciones = [
      (filtro: 1, texto: 'Aciertos', cantidad: _items.length - _totalErrores, color: _success, icono: Icons.check_rounded),
      (filtro: 0, texto: 'Errores', cantidad: _totalErrores, color: _danger, icono: Icons.close_rounded),
      (filtro: 2, texto: 'Todas', cantidad: _items.length, color: _primary, icono: Icons.list_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (int i = 0; i < opciones.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _cambiarFiltro(opciones[i].filtro),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _filtro == opciones[i].filtro ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _filtro == opciones[i].filtro
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(opciones[i].icono, size: 15, color: _filtro == opciones[i].filtro ? opciones[i].color : _muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${opciones[i].texto} ${opciones[i].cantidad}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _filtro == opciones[i].filtro ? FontWeight.w800 : FontWeight.w600,
                            color: _filtro == opciones[i].filtro ? opciones[i].color : _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _progresoRepaso(int repasadas, int total) {
    final completo = repasadas >= total;
    final color = completo ? _success : _exam;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completo ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(completo ? Icons.celebration_rounded : Icons.fitness_center_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  completo
                      ? '¡Repasaste todos tus errores! Ya estás listo para intentarlo de nuevo.'
                      : 'Repasaste $repasadas de $total errores',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: total == 0 ? 0 : repasadas / total),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                minHeight: 7,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacioFiltro() {
    final sinErrores = _filtro == 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(sinErrores ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded,
              size: 40, color: sinErrores ? _warn : _muted),
          const SizedBox(height: 8),
          Text(
            sinErrores ? 'No tuviste errores en este examen.' : 'Esta vez no hubo aciertos. ¡Tú puedes!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text),
          ),
        ],
      ),
    );
  }

  Widget _encabezadoPregunta(int numero, String pregunta, Color color, IconData icono) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$numero',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              pregunta,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text, height: 1.4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icono, color: color, size: 20),
      ],
    );
  }

  Widget _tarjetaAcierto(
      ({int numero, String pregunta, bool correcta, String tuRespuesta, String respuestaCorrecta}) item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezadoPregunta(item.numero, item.pregunta, _success, Icons.check_circle_rounded),
          const SizedBox(height: 12),
          RespuestaFila(correcta: true, etiqueta: 'Tu respuesta', texto: item.tuRespuesta),
        ],
      ),
    );
  }

  Widget _tarjetaFallo(
      ({int numero, String pregunta, bool correcta, String tuRespuesta, String respuestaCorrecta}) item) {
    final revelada = _reveladas.contains(item.numero);
    final repasada = _repasadas.contains(item.numero);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: repasada ? _success : _border,
          width: repasada ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (repasada ? _success : _danger).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezadoPregunta(
            item.numero,
            item.pregunta,
            repasada ? _success : _danger,
            repasada ? Icons.task_alt_rounded : Icons.cancel_rounded,
          ),
          const SizedBox(height: 12),
          RespuestaFila(correcta: false, etiqueta: 'Tu respuesta', texto: item.tuRespuesta),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 320),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: revelada ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: GestureDetector(
              onTap: () => setState(() => _reveladas.add(item.numero)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _exam.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: _exam, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '¿Ya sabes cuál era? Toca para ver la respuesta correcta',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _exam),
                      ),
                    ),
                    Icon(Icons.touch_app_rounded, color: _exam, size: 20),
                  ],
                ),
              ),
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RespuestaFila(correcta: true, etiqueta: 'Respuesta correcta', texto: item.respuestaCorrecta),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (repasada) {
                        _repasadas.remove(item.numero);
                      } else {
                        _repasadas.add(item.numero);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: repasada ? _success : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _success, width: 1.4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            repasada ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: repasada ? Colors.white : _success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            repasada ? 'Repasada' : 'Ya la entendí',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: repasada ? Colors.white : _success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaIA() {
    return GestureDetector(
      onTap: _abrirFundamentos,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _exam.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: BrilloDeslizante(
          borderRadius: BorderRadius.circular(22),
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (context, child) {
              final double shift = math.sin(_ambient.value * 2 * math.pi) * 0.4;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + shift, -1),
                    end: Alignment(1 - shift, 1),
                    colors: const [Color(0xFF0D47A1), _primary, _exam],
                  ),
                ),
                child: child,
              );
            },
            child: Row(
              children: [
                Flotante(
                  amplitud: 3,
                  escala: 0.06,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: EncabezadoAzul.decoracionVidrio,
                    child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '¿Por qué me equivoqué?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'La IA te explica el fundamento teórico de cada error.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, color: _primary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaPerfecta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Flotante(
            amplitud: 3,
            rotacion: 0.18,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.celebration_rounded, color: _success, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Examen perfecto!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
                SizedBox(height: 4),
                Text(
                  'No tuviste errores. Sigue así con la siguiente sección.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              EncabezadoAzul(
                title: 'Resultados',
                subtitle: 'Examen de la sección',
                grande: true,
                leading: EncabezadoAzul.boton(
                  icon: Icons.close_rounded,
                  grande: true,
                  size: 24,
                  onTap: () => Navigator.of(context).pop(true),
                ),
                trailing: EncabezadoAzul.boton(
                  icon: Icons.home_outlined,
                  grande: true,
                  size: 25,
                  onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
              AnchoMaximo(
                maximo: 760,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildHero(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _statTile(
                            icon: Icons.check_circle_rounded,
                            valor: '${widget.correctas}',
                            etiqueta: 'Correctas',
                            color: _success,
                            fase: 0,
                            activo: _items.isNotEmpty && _filtro == 1,
                            onTap: _items.isEmpty ? null : () => _cambiarFiltro(1),
                          ),
                          const SizedBox(width: 12),
                          _statTile(
                            icon: Icons.cancel_rounded,
                            valor: '${widget.incorrectas}',
                            etiqueta: 'Incorrectas',
                            color: _danger,
                            fase: 2.1,
                            activo: _items.isNotEmpty && _filtro == 0,
                            onTap: _items.isEmpty ? null : () => _cambiarFiltro(0),
                          ),
                          const SizedBox(width: 12),
                          _statTile(
                            icon: Icons.quiz_rounded,
                            valor: '${widget.totalPreguntas}',
                            etiqueta: 'Total',
                            color: _primary,
                            fase: 4.2,
                            activo: _items.isNotEmpty && _filtro == 2,
                            onTap: _items.isEmpty ? null : () => _cambiarFiltro(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (widget.erroresDelExamen.isNotEmpty) ...[
                        _tarjetaIA(),
                        const SizedBox(height: 28),
                      ] else ...[
                        _tarjetaPerfecta(),
                        const SizedBox(height: 28),
                      ],
                      if (_items.isNotEmpty) _zonaRevision(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: _primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Ver plan de estudio',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          side: const BorderSide(color: _primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Volver a mis cursos',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  final double progreso;
  final Color color;
  final double brillo;

  _AnilloPainter({required this.progreso, required this.color, required this.brillo});

  @override
  void paint(Canvas canvas, Size size) {
    const double grosor = 14;
    final Offset centro = size.center(Offset.zero);
    final double radio = (size.shortestSide - grosor) / 2;
    final Rect rect = Rect.fromCircle(center: centro, radius: radio);

    final Paint pista = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = const Color(0xFFEEF2F7);
    canvas.drawCircle(centro, radio, pista);

    if (progreso <= 0) return;

    final double sweep = 2 * math.pi * progreso;
    final Paint arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arco);

    final double ang = -math.pi / 2 + sweep;
    final Offset punto = centro + Offset(math.cos(ang) * radio, math.sin(ang) * radio);
    canvas.drawCircle(
      punto,
      grosor * 0.5 + 4 * brillo,
      Paint()..color = color.withValues(alpha: 0.18 + 0.14 * brillo),
    );
    canvas.drawCircle(punto, grosor * 0.3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AnilloPainter old) =>
      old.progreso != progreso || old.color != color || old.brillo != brillo;
}