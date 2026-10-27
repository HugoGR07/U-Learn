import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/progreso_local_service.dart';
import 'lesson_view.dart';
import 'exam_view.dart';
import 'result_view.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/componentes_guia.dart';
import '../widgets/efectos_animados.dart';
import '../widgets/ruta_suave.dart';

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
  final Map<int, Set<int>> _vistos = {};
  final Set<int> _abiertas = {};
  bool _abiertasIniciadas = false;

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
      child: RepaintBoundary(
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
      ),
    );
  }

  bool _cargandoDetalles = false;

  Future<void> _fetchCourseDetails({bool silencioso = false}) async {
    if (_cargandoDetalles) return;
    _cargandoDetalles = true;
    if (_secciones.isEmpty) setState(() => _isLoading = true);

    final res = await ApiService.getGuideDetails(widget.idGuia);
    _cargandoDetalles = false;

    if (!mounted) return;

    if (res['success'] == true) {
      final secciones = List<dynamic>.from(res['data']?['secciones'] ?? []);
      final vistos = await _leerVistos(secciones);
      if (!mounted) return;
      setState(() {
        _guia = res['data']?['guia'] as Map<String, dynamic>?;
        _secciones = secciones;
        _vistos
          ..clear()
          ..addAll(vistos);
        _isLoading = false;
        if (!_abiertasIniciadas) {
          _abiertasIniciadas = true;
          final actual = _secciones.indexWhere((s) => s['completado'] != true);
          _abiertas.add(actual >= 0 ? actual : 0);
        }
      });
    } else {
      setState(() => _isLoading = false);
      if (silencioso && _secciones.isNotEmpty) return;
      AlertaFlotante.mostrar(
        context,
        titulo: 'No se pudo cargar tu guía',
        mensaje: res['message']?.toString() ?? 'No pudimos abrir tu guía. Inténtalo de nuevo.',
        tipo: TipoAlerta.error,
      );
    }
  }

  Future<Map<int, Set<int>>> _leerVistos(List<dynamic> secciones) async {
    final ids = secciones.map((sec) => sec is Map ? sec['id_seccion'] : null).whereType<int>().toList();
    final vistos = await Future.wait(ids.map(ProgresoLocalService.vistos));
    return {for (int i = 0; i < ids.length; i++) ids[i]: vistos[i]};
  }

  Future<void> _actualizarVistosDe(int idSeccion) async {
    final vistos = await ProgresoLocalService.vistos(idSeccion);
    if (!mounted) return;
    setState(() => _vistos[idSeccion] = vistos);
  }

  void _marcarCompletada(int idSeccion) {
    final i = _secciones.indexWhere((s) => s is Map && s['id_seccion'] == idSeccion);
    if (i < 0) return;
    setState(() {
      _secciones = [..._secciones];
      _secciones[i] = {...Map<String, dynamic>.from(_secciones[i] as Map), 'completado': true};
    });
  }

  Set<int> _vistosDe(Map<String, dynamic> sec) {
    final id = sec['id_seccion'];
    return id is int ? (_vistos[id] ?? <int>{}) : <int>{};
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
      RutaSuave(
        page: LessonView(
          idSeccion: sec['id_seccion'],
          numeroSeccion: sectionIndex + 1,
          tituloSeccion: sec['titulo'] ?? '',
          lessons: lessons,
          currentIndex: lessonIndex,
          tieneExamen: examen != null,
          seccionCompletada: sec['completado'] == true,
          nombreGuia: (_guia?['nombre_tema'] ?? '').toString(),
        ),
      ),
    );

    if (!mounted) return;
    final idSeccion = sec['id_seccion'];
    if (idSeccion is int) {
      await _actualizarVistosDe(idSeccion);
      if (result == 'examen') _marcarCompletada(idSeccion);
    }
    if (!mounted) return;
    if (result == 'examen' && examen != null) {
      final fresh = Map<String, dynamic>.from(
        _secciones.firstWhere(
          (s) => s is Map && s['id_seccion'] == idSeccion,
          orElse: () => sec,
        ) as Map,
      );
      final freshExam = (fresh['examen'] as Map<String, dynamic>?) ?? examen;
      if (freshExam['intentos'] is Map) {
        _fetchCourseDetails(silencioso: true);
        _showRetakeDialog(fresh, sectionIndex, freshExam);
        return;
      }
      await _openExam(fresh, sectionIndex, freshExam);
    } else {
      _fetchCourseDetails(silencioso: true);
    }
  }

  Future<void> _openExam(Map<String, dynamic> sec, int sectionIndex, Map<String, dynamic> examen) async {
    // Navegación a la vista del examen
    await Navigator.push(
      context,
      RutaSuave(
        page: ExamView(
          examen: {
            ...examen,
            'titulo': 'Examen · Sección ${sectionIndex + 1}',
            'numero_seccion': sectionIndex + 1,
            'titulo_seccion': (sec['titulo'] ?? '').toString(),
            'nombre_guia': (_guia?['nombre_tema'] ?? '').toString(),
          },
          idSeccion: sec['id_seccion'],
        ),
      ),
    );

    if (mounted) _fetchCourseDetails(silencioso: true);
  }

  static const int _notaAprobatoria = 60;

  int _pct(dynamic v) => (num.tryParse(v?.toString() ?? '') ?? 0).round();

  Future<void> _showRetakeDialog(Map<String, dynamic> sec, int sectionIndex, Map<String, dynamic> examen) async {
    final intentos = Map<String, dynamic>.from(examen['intentos'] as Map);
    final int ultima = _pct(intentos['ultima_calificacion']);
    final int mejor = _pct(intentos['mejor_calificacion']);
    final int total = int.tryParse(intentos['total_intentos']?.toString() ?? '') ?? 1;
    final bool aprobado = ultima >= _notaAprobatoria;
    final Color color = aprobado ? _success : const Color(0xFFF59E0B);
    bool verResultados = false;

    final repetir = await AlertaFlotante.confirmar(
      context,
      titulo: 'Ya presentaste este examen',
      icono: aprobado ? Icons.emoji_events_rounded : Icons.stars_rounded,
      colorIcono: aprobado ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
      fondoIcono: aprobado ? const Color(0xFFFEF9C3) : const Color(0xFFF1F5F9),
      tipo: TipoAlerta.info,
      textoConfirmar: 'Sí, repetir',
      textoCancelar: 'No',
      colorConfirmar: _exam,
      botonesEnFila: true,
      contenido: Column(
        children: [
          const Text('Tu última calificación', style: TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ultima.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => Text(
              '${valor.round()}%',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total > 1
                ? 'Mejor calificación: $mejor% · $total intentos'
                : '1 intento realizado',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (dialogContext) => TextButton.icon(
              onPressed: () {
                verResultados = true;
                Navigator.of(dialogContext).pop(false);
              },
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text(
                'Ver mis resultados',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _exam,
                backgroundColor: const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '¿Quieres volver a hacer el examen?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _text, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (verResultados) {
      _abrirResultados(examen);
      return;
    }
    if (repetir) _openExam(sec, sectionIndex, examen);
  }

  int _entero(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  List<Map<String, dynamic>> _listaMapas(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _abrirResultados(Map<String, dynamic> examen) async {
    final idExamen = int.tryParse(examen['id_examen']?.toString() ?? '');
    if (idExamen == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _primary)),
    );
    final res = await ApiService.getLastAttempt(idExamen);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (res['success'] != true) {
      AlertaFlotante.mostrar(
        context,
        titulo: 'No se pudieron abrir tus resultados',
        mensaje: res['message']?.toString() ?? 'Inténtalo de nuevo en un momento.',
        tipo: TipoAlerta.error,
      );
      return;
    }

    final data = Map<String, dynamic>.from(res['data'] as Map);
    final resultado = data['resultado'] is Map ? Map<String, dynamic>.from(data['resultado'] as Map) : <String, dynamic>{};
    final total = _entero(resultado['totalPreguntas']);
    final correctas = _entero(resultado['correctas']);

    await Navigator.push(
      context,
      RutaSuave(
        page: ResultView(
          totalPreguntas: total,
          correctas: correctas,
          incorrectas: _entero(resultado['incorrectas']),
          porcentaje: _pct(resultado['calificacion']),
          erroresDelExamen: _listaMapas(data['errores']),
          examenCompleto: _listaMapas(data['examen_completo']),
        ),
      ),
    );
  }

  void _showLockedDialog() {
    AlertaFlotante.mostrar(
      context,
      titulo: 'Sección bloqueada',
      mensaje: 'Debes completar todas las lecciones de esta sección para desbloquear el examen.',
      tipo: TipoAlerta.aviso,
      icono: Icons.lock_clock_rounded,
      textoBoton: 'Continuar',
      cerrarAlTocarFuera: true,
    );
  }

  int get _seccionesCompletadas => _secciones.where((s) => s is Map && s['completado'] == true).length;

  int get _examenesPresentados => _secciones
      .where((s) => s is Map && s['examen'] is Map && (s['examen'] as Map)['intentos'] is Map)
      .length;

  int get _examenesTotales => _secciones.where((s) => s is Map && s['examen'] is Map).length;

  int get _temasVistos {
    int total = 0;
    for (final s in _secciones) {
      if (s is! Map) continue;
      final cantidad = (s['contenidos'] as List?)?.length ?? 0;
      if (s['completado'] == true) {
        total += cantidad;
      } else {
        total += _vistosDe(Map<String, dynamic>.from(s)).where((v) => v < cantidad).length;
      }
    }
    return total;
  }

  int get _temasTotales => _secciones.fold<int>(
        0,
        (suma, s) => suma + (s is Map ? ((s['contenidos'] as List?)?.length ?? 0) : 0),
      );

  Widget _chip(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: _primary),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _tarjetaProgreso(String titulo, String descripcion) {
    final total = _secciones.length;
    final hechas = _seccionesCompletadas;
    final pasos = total + _examenesTotales;
    final progreso = pasos == 0 ? 0.0 : ((hechas + _examenesPresentados) / pasos).clamp(0.0, 1.0);

    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _primary.withValues(alpha: 0.22), width: 1.5),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: _primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: BrilloDeslizante(
        borderRadius: BorderRadius.circular(26),
        intensidad: 0.14,
        periodo: const Duration(milliseconds: 4500),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFFEBF2FE)),
          child: Stack(
            children: [
              const Positioned.fill(child: IgnorePointer(child: _FondoAnimado(color: _primary))),
              Positioned(
                top: 14,
                right: 18,
                child: Flotante(
                  amplitud: 5,
                  rotacion: 0.12,
                  child: Icon(Icons.savings_rounded, size: 40, color: _primary.withValues(alpha: 0.10)),
                ),
              ),
              Positioned(
                bottom: 60,
                right: 70,
                child: Flotante(
                  amplitud: 4,
                  fase: 2,
                  child: Icon(Icons.trending_up_rounded, size: 26, color: _primary.withValues(alpha: 0.08)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flotante(
                          amplitud: 3,
                          escala: 0.05,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(17),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(IconosFinanzas.para(titulo, 0), color: _primary, size: 28),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _text),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                descripcion,
                                textAlign: TextAlign.justify,
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
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          '${(progreso * 100).round()}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progreso),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, valor, _) => LinearProgressIndicator(
                                value: valor,
                                minHeight: 9,
                                color: _primary,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(Icons.layers_rounded, '$hechas/$total secciones'),
                        _chip(Icons.menu_book_rounded, '$_temasVistos/$_temasTotales temas'),
                        _chip(Icons.emoji_events_rounded, '$_examenesPresentados/$_examenesTotales exámenes'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _tocarExamen(Map<String, dynamic> sec, int sectionIndex, Map<String, dynamic> examen) {
    if (sec['completado'] != true) {
      _showLockedDialog();
      return;
    }
    if (examen['intentos'] is Map) {
      _showRetakeDialog(sec, sectionIndex, examen);
      return;
    }
    _openExam(sec, sectionIndex, examen);
  }

  ({int seccion, int tema})? get _siguientePaso {
    for (int i = 0; i < _secciones.length; i++) {
      final s = _secciones[i];
      if (s is! Map || s['completado'] == true) continue;
      final sec = Map<String, dynamic>.from(s);
      final total = (sec['contenidos'] as List?)?.length ?? 0;
      if (total == 0) continue;
      final p = ProgresoLocalService.primerPendiente(_vistosDe(sec), total);
      return (seccion: i, tema: p >= 0 ? p : total - 1);
    }
    return null;
  }

  Widget _tarjetaContinuar() {
    final paso = _siguientePaso;
    if (paso == null) return const SizedBox.shrink();
    final sec = Map<String, dynamic>.from(_secciones[paso.seccion] as Map);
    final contenidos = sec['contenidos'] as List<dynamic>? ?? [];
    final tema = (contenidos[paso.tema]['titulo'] ?? 'Tema ${paso.tema + 1}').toString();

    return _PressScale(
      onTap: () => _openLesson(sec, paso.seccion, paso.tema),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withValues(alpha: 0.25), width: 1.4),
          boxShadow: [
            BoxShadow(color: _primary.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _exam]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTINÚA DONDE TE QUEDASTE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: _primary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tema,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _text, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sección ${paso.seccion + 1} · Tema ${paso.tema + 1} de ${contenidos.length}',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _primary),
          ],
        ),
      ),
    );
  }

  Widget _anilloSeccion({required double progreso, required bool completada, required bool actual, required int numero}) {
    final color = completada ? _success : (actual ? _primary : const Color(0xFF94A3B8));
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progreso),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: valor,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.14),
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completada ? _success : (actual ? _primary : const Color(0xFFF1F5F9)),
            ),
            alignment: Alignment.center,
            child: completada
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Text(
                    '$numero',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: actual ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(bool completada, bool actual) {
    final (texto, color) = completada
        ? ('Completada', _success)
        : actual
            ? ('En curso', _primary)
            : ('Pendiente', const Color(0xFF94A3B8));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _tarjetaModulo(Map<String, dynamic> sec, int indice) {
    final contenidos = sec['contenidos'] as List<dynamic>? ?? [];
    final examen = sec['examen'] as Map<String, dynamic>?;
    final completada = sec['completado'] == true;
    final actual = indice == _currentSectionIndex;
    final abierta = _abiertas.contains(indice);
    final vistos = _vistosDe(sec);
    final cuantos = completada ? contenidos.length : vistos.where((v) => v < contenidos.length).length;
    final progreso = contenidos.isEmpty ? 0.0 : cuantos / contenidos.length;
    final pendiente = ProgresoLocalService.primerPendiente(vistos, contenidos.length);
    final intentos = examen != null && examen['intentos'] is Map ? examen['intentos'] as Map : null;
    final Color acento = completada ? _success : _primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: actual ? _primary.withValues(alpha: 0.45) : (abierta ? acento.withValues(alpha: 0.25) : _border),
          width: actual ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: (actual ? _primary : Colors.black).withValues(alpha: actual ? 0.12 : 0.04),
            blurRadius: actual ? 14 : 8,
            offset: Offset(0, actual ? 6 : 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() {
              if (abierta) {
                _abiertas.remove(indice);
              } else {
                _abiertas.add(indice);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  _anilloSeccion(progreso: progreso, completada: completada, actual: actual, numero: indice + 1),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'SECCIÓN ${indice + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: completada || actual ? acento : _muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _estadoChip(completada, actual),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (sec['titulo'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: _text, height: 1.25),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 14, color: _muted),
                            const SizedBox(width: 4),
                            Text(
                              '$cuantos/${contenidos.length} temas',
                              style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600),
                            ),
                            if (examen != null) ...[
                              const SizedBox(width: 12),
                              Icon(
                                intentos != null ? Icons.emoji_events_rounded : Icons.quiz_outlined,
                                size: 14,
                                color: intentos != null ? const Color(0xFFF59E0B) : _muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                intentos != null
                                    ? 'Examen ${_pct(intentos['ultima_calificacion'])}%'
                                    : (completada ? 'Examen listo' : 'Examen'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: intentos != null ? const Color(0xFFB45309) : _muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !abierta
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      child: Column(
                        children: [
                          const Divider(height: 1, color: _border),
                          const SizedBox(height: 12),
                          ...contenidos.asMap().entries.map((e) => _buildLessonItem(
                                title: (e.value['titulo'] ?? 'Tema ${e.key + 1}').toString(),
                                isCompleted: completada,
                                visto: vistos.contains(e.key),
                                lessonNumber: e.key + 1,
                                showConnector: e.key < contenidos.length - 1 || examen != null,
                                onTap: () => _openLesson(sec, indice, e.key),
                              )),
                          if (examen != null)
                            _buildExamItem(
                              examen: examen,
                              isUnlocked: completada,
                              onTap: () => _tocarExamen(sec, indice, examen),
                            ),
                          if (!completada && contenidos.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _PressScale(
                              onTap: () => _openLesson(sec, indice, pendiente >= 0 ? pendiente : contenidos.length - 1),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_primary, _exam]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(color: _primary.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 5)),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: _shimmer()),
                                    Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Text(
                                            cuantos == 0 ? 'Comenzar sección' : 'Continuar sección',
                                            style: const TextStyle(
                                              fontSize: 14.5,
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
          onRefresh: () => _fetchCourseDetails(silencioso: true),
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
                AnchoMaximo(
                  maximo: 760,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // 2. Tarjeta Informativa del Curso
                        Aparecer(
                          orden: 0,
                          duracion: const Duration(milliseconds: 320),
                          pasoMs: 40,
                          desplazamiento: 14,
                          child: _tarjetaProgreso(title, description),
                        ),

                        const SizedBox(height: 28),

                        if (_siguientePaso != null) ...[
                          Aparecer(
                            orden: 1,
                            duracion: const Duration(milliseconds: 320),
                            pasoMs: 40,
                            desplazamiento: 14,
                            child: _tarjetaContinuar(),
                          ),
                          const SizedBox(height: 28),
                        ],

                        const EtiquetaSeccion(icono: Icons.route_rounded, texto: 'Ruta de aprendizaje'),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.only(left: 38),
                          child: Text(
                            'Toca una sección para ver sus temas y su examen.',
                            textAlign: TextAlign.justify,
                            style: TextStyle(fontSize: 13, color: _muted),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Renderizado de Secciones, Lecciones y Examen Final de Sección
                        for (int i = 0; i < _secciones.length; i++)
                          Aparecer(
                            orden: (i + 2).clamp(0, 6),
                            duracion: const Duration(milliseconds: 320),
                            pasoMs: 40,
                            desplazamiento: 14,
                            child: _tarjetaModulo(Map<String, dynamic>.from(_secciones[i] as Map), i),
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
      ),
    );
  }

  // Widget para renderizar cada Lección
  Widget _buildLessonItem({
    required String title,
    bool isCompleted = false,
    bool visto = false,
    int? lessonNumber,
    bool showConnector = true,
    required VoidCallback onTap,
  }) {
    final Color colorCirculo = isCompleted || visto ? _success : _primary;
    final Widget contenidoCirculo = isCompleted || visto
        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
        : Text(
            '$lessonNumber',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          );

    return Stack(
      children: [
        if (showConnector)
          Positioned(
            left: 14,
            top: 38,
            bottom: 0,
            width: 2,
            child: ColoredBox(
              color: isCompleted
                  ? _success.withValues(alpha: 0.4)
                  : const Color(0xFFC7D7FB),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted || visto ? colorCirculo : Colors.white,
                      border: Border.all(color: colorCirculo, width: 2),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: KeyedSubtree(
                          key: ValueKey('${isCompleted}_$visto'),
                          child: contenidoCirculo,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PressScale(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
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
      ],
    );
  }

  // Widget para renderizar la tarjeta del Examen al final de la Sección
  Widget _buildExamItem({
    required Map<String, dynamic> examen,
    required bool isUnlocked,
    required VoidCallback onTap,
  }) {
    final int totalPreguntas = (examen['preguntas'] as List?)?.length ?? 0;
    final intentos = examen['intentos'] is Map ? examen['intentos'] as Map : null;
    final int? ultima = intentos != null ? _pct(intentos['ultima_calificacion']) : null;
    final Color scoreColor =
        (ultima ?? 0) >= _notaAprobatoria ? _success : const Color(0xFFF59E0B);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: isUnlocked
                  ? RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) => Transform.scale(
                          scale: 1 + math.sin(_floatController.value * 2 * math.pi) * 0.12,
                          child: child,
                        ),
                        child: const Icon(Icons.flag_rounded, color: _exam, size: 22),
                      ),
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
                          !isUnlocked
                              ? 'Completa los temas para desbloquear'
                              : ultima != null
                                  ? 'Presentado · toca para ver o repetir'
                                  : '$totalPreguntas preguntas',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnlocked ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnlocked && ultima != null)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$ultima%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
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
class _FondoAnimado extends StatefulWidget {
  final Color color;

  const _FondoAnimado({required this.color});

  @override
  State<_FondoAnimado> createState() => _FondoAnimadoState();
}

class _FondoAnimadoState extends State<_FondoAnimado> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PintorFondo(_c, widget.color),
      ),
    );
  }
}

class _PintorFondo extends CustomPainter {
  final Animation<double> t;
  final Color color;

  _PintorFondo(this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * math.pi;

    final burbujas = [
      (x: 0.88, y: 0.12, r: 0.42, dx: 0.06, dy: 0.08, fase: 0.0, alfa: 0.10),
      (x: 0.10, y: 0.95, r: 0.36, dx: 0.08, dy: 0.05, fase: 2.1, alfa: 0.08),
      (x: 0.55, y: 0.70, r: 0.22, dx: 0.10, dy: 0.07, fase: 4.0, alfa: 0.07),
      (x: 0.30, y: 0.15, r: 0.16, dx: 0.07, dy: 0.06, fase: 1.2, alfa: 0.06),
    ];

    for (final b in burbujas) {
      final centro = Offset(
        size.width * (b.x + math.sin(a + b.fase) * b.dx),
        size.height * (b.y + math.cos(a * 1.3 + b.fase) * b.dy),
      );
      final radio = size.shortestSide * b.r * (1 + 0.06 * math.sin(a * 2 + b.fase));
      final pintura = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: b.alfa), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centro, radius: radio));
      canvas.drawCircle(centro, radio, pintura);
    }

    final onda = Path();
    final base = size.height * 0.86;
    onda.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 6) {
      final y = base + math.sin((x / size.width) * 2 * math.pi + a) * 7 + math.sin((x / size.width) * 4 * math.pi - a * 2) * 3;
      onda.lineTo(x, y);
    }
    onda.lineTo(size.width, size.height);
    onda.close();
    canvas.drawPath(onda, Paint()..color = color.withValues(alpha: 0.05));
  }

  @override
  bool shouldRepaint(covariant _PintorFondo old) => old.color != color;
}