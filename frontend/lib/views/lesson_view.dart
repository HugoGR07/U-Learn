import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/conexion_service.dart';
import '../services/progreso_local_service.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/componentes_guia.dart';

class LessonView extends StatefulWidget {
  final int idSeccion;
  final int numeroSeccion;
  final String tituloSeccion;
  final List<Map<String, dynamic>> lessons;
  final int currentIndex;
  final bool tieneExamen;
  final bool seccionCompletada;
  final String nombreGuia;

  const LessonView({
    super.key,
    required this.idSeccion,
    required this.numeroSeccion,
    required this.tituloSeccion,
    required this.lessons,
    required this.currentIndex,
    this.tieneExamen = true,
    this.seccionCompletada = false,
    this.nombreGuia = '',
  });

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  static const Color _primary = Color(0xFF1D61E7);
  static const Color _text = Color(0xFF1E293B);
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
    _registrarVisto(_index);
    ApiService.startSection(widget.idSeccion);
  }

  bool _enviada = false;
  Future<bool>? _envio;

  Future<bool> _asegurarCompleta() {
    if (widget.seccionCompletada || _enviada) return Future.value(true);
    return _envio ??= ApiService.completeSection(widget.idSeccion).then((ok) {
      if (ok) {
        _enviada = true;
        final seccion = widget.tituloSeccion.trim().isEmpty ? '' : ' «${widget.tituloSeccion.trim()}»';
        final guia = widget.nombreGuia.trim().isEmpty ? '' : ' de «${widget.nombreGuia.trim()}»';
        NotificationService.showProgress(
          '¡Sección ${widget.numeroSeccion} completada! ✅',
          widget.tieneExamen
              ? 'Terminaste los temas$seccion$guia. Ya puedes presentar su examen.'
              : 'Terminaste los temas$seccion$guia. Sigue así.',
        );
        NotificationService.refreshReminder();
      } else {
        _envio = null;
      }
      return ok;
    });
  }

  Future<void> _registrarVisto(int indice) async {
    await ProgresoLocalService.marcarVisto(widget.idSeccion, indice);
    if (widget.seccionCompletada || _enviada) return;
    final vistos = await ProgresoLocalService.vistos(widget.idSeccion);
    if (ProgresoLocalService.primerPendiente(vistos, widget.lessons.length) < 0) {
      _asegurarCompleta();
    }
  }

  Future<void> _salir() async {
    final envio = _envio;
    if (envio != null) {
      try {
        await envio.timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context, true);
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
    _registrarVisto(index);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finishSection() async {
    final vistos = await ProgresoLocalService.vistos(widget.idSeccion);
    vistos.add(_index);
    final pendiente = ProgresoLocalService.primerPendiente(vistos, widget.lessons.length);
    if (pendiente >= 0) {
      if (!mounted) return;
      final faltan = [
        for (int i = 0; i < widget.lessons.length; i++)
          if (!vistos.contains(i)) _tituloLeccion(i),
      ];
      final ir = await AlertaFlotante.confirmar(
        context,
        titulo: 'Te faltan temas por revisar',
        mensaje: 'Para ${widget.tieneExamen ? 'presentar el examen' : 'terminar la sección'} primero revisa ${_lista(faltan)}.',
        tipo: TipoAlerta.aviso,
        icono: Icons.menu_book_rounded,
        textoConfirmar: 'Ir al tema',
        textoCancelar: 'Ahora no',
      );
      if (ir && mounted) _goTo(pendiente);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = true);
    if (!await ApiService.hayInternet()) {
      if (!mounted) return;
      setState(() => _busy = false);
      AlertaFlotante.mostrar(
        context,
        titulo: 'Sin conexión',
        mensaje: ConexionService.mensajeSinInternet,
        tipo: TipoAlerta.sinConexion,
      );
      return;
    }
    final ok = await _asegurarCompleta();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, widget.tieneExamen ? 'examen' : true);
    } else {
      setState(() => _busy = false);
      AlertaFlotante.mostrar(
        context,
        titulo: 'No se guardó tu avance',
        mensaje: 'No se pudo registrar tu avance. Inténtalo de nuevo.',
        tipo: TipoAlerta.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLesson = widget.lessons[_index];
    final totalLessons = widget.lessons.length;
    final bool isLast = _index == totalLessons - 1;
    final estructura = _parseContenido(currentLesson['contenido']);
    final horizontal = context.esHorizontal;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12, horizontal ? 4 : 12, 24, 0),
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
                          onPressed: _salir,
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
                    SizedBox(height: horizontal ? 4 : 10),

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
                  child: AnchoMaximo(
                    maximo: 760,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(_index),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 22),
                          Text(
                            'TEMA ${_index + 1} DE $totalLessons',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // 3. Título de la Lección
                          Text(
                            (currentLesson['titulo'] ?? 'Título de Lección').toString(),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: _text,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 18),
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
              ),

              // 5. Botones Inferiores (Anterior / Siguiente)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: horizontal ? 8.0 : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index > 0 && !_busy ? () => _goTo(_index - 1) : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, horizontal ? 44 : 50),
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
                          minimumSize: Size(double.infinity, horizontal ? 44 : 50),
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
      ),
    );
  }

  String _tituloLeccion(int i) {
    if (i < 0 || i >= widget.lessons.length) return '';
    return (widget.lessons[i]['titulo'] ?? '').toString().trim();
  }

  String _lista(List<String> titulos) {
    final t = titulos.where((x) => x.isNotEmpty).map((x) => '«$x»').toList();
    if (t.isEmpty) return '';
    if (t.length == 1) return t.first;
    return '${t.sublist(0, t.length - 1).join(', ')} y ${t.last}';
  }

  String _textoConexion(Map<String, dynamic>? data) {
    final seccion = (data?['conexion_seccion'] ?? '').toString().trim();
    final previa = (data?['conexion_previa'] ?? '').toString().trim();
    final partes = [
      if (_index == 0 && seccion.isNotEmpty) seccion,
      if (previa.isNotEmpty) previa,
    ];
    if (partes.isNotEmpty) return partes.join(' ');

    final actual = _tituloLeccion(_index);
    if (_index > 0) {
      return 'En el tema anterior viste «${_tituloLeccion(_index - 1)}». Ahora das el siguiente paso con «$actual», que se apoya en eso.';
    }
    final siguientes = [for (int i = 1; i < widget.lessons.length; i++) _tituloLeccion(i)];
    if (siguientes.isEmpty) {
      return 'Este tema reúne lo esencial de la sección «${widget.tituloSeccion}».';
    }
    return 'Aquí arranca la sección «${widget.tituloSeccion}». Lo que veas en «$actual» es la base para ${_lista(siguientes)}.';
  }

  String _textoSiguiente(Map<String, dynamic>? data) {
    final puente = (data?['puente_siguiente'] ?? '').toString().trim();
    if (puente.isNotEmpty) return puente;

    final actual = _tituloLeccion(_index);
    if (_index < widget.lessons.length - 1) {
      return 'Con «$actual» claro, el siguiente paso es «${_tituloLeccion(_index + 1)}», donde vas a usar lo que acabas de aprender.';
    }
    final todos = [for (int i = 0; i < widget.lessons.length; i++) _tituloLeccion(i)];
    if (widget.tieneExamen) {
      return 'Ya recorriste ${_lista(todos)}. En el examen vas a combinar estas ideas para resolver casos reales.';
    }
    return 'Con esto cierras la sección «${widget.tituloSeccion}» y quedas listo para la siguiente.';
  }

  Widget _tarjetaConexion(Map<String, dynamic>? data) {
    return _aviso(
      icono: _index == 0 ? Icons.flag_outlined : Icons.link_rounded,
      titulo: _index == 0 ? 'Punto de partida' : 'Viene de lo anterior',
      texto: _textoConexion(data),
      color: const Color(0xFF7C3AED),
      fondo: const Color(0xFFF5F3FF),
    );
  }

  Widget _tarjetaSiguiente(Map<String, dynamic>? data) {
    final ultimo = _index == widget.lessons.length - 1;
    return _aviso(
      icono: ultimo ? Icons.flag_rounded : Icons.arrow_forward_rounded,
      titulo: ultimo ? (widget.tieneExamen ? 'Rumbo al examen' : 'Cierre de la sección') : 'Lo que sigue',
      texto: _textoSiguiente(data),
      color: const Color(0xFF4F46E5),
      fondo: const Color(0xFFEEF2FF),
    );
  }

  Widget _parrafo(String texto, {double tamano = 15.5}) {
    return TextoConDinero(
      texto,
      acento: _primary,
      tamano: tamano,
      color: const Color(0xFF334155),
      altura: 1.7,
      alineacion: TextAlign.justify,
    );
  }

  Widget _titulo(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, size: 20, color: _primary),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _text),
          ),
        ],
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text),
      ),
    );
  }

  Widget _aviso({
    required IconData icono,
    required String titulo,
    required String texto,
    required Color color,
    required Color fondo,
    String? nota,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  titulo,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextoConDinero(
            texto,
            acento: color,
            tamano: 14,
            color: const Color(0xFF334155),
            altura: 1.55,
            alineacion: TextAlign.justify,
          ),
          if (nota != null) ...[
            const SizedBox(height: 10),
            _notaCifras(nota, color),
          ],
        ],
      ),
    );
  }

  static final RegExp _hayCifras = RegExp(r'(\$\s?\d|\d\s?(?:MXN|pesos)|\d\s?%)', caseSensitive: false);

  Widget _notaCifras(String texto, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaConcepto(int numero, String titulo, String texto, {bool esUltimo = false}) {
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
                  decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '$numero',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                if (!esUltimo)
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
              margin: EdgeInsets.only(bottom: esUltimo ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo.isNotEmpty)
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _text),
                    ),
                  if (titulo.isNotEmpty && texto.isNotEmpty) const SizedBox(height: 4),
                  if (texto.isNotEmpty)
                    TextoConDinero(
                      texto,
                      acento: _primary,
                      tamano: 13.5,
                      color: const Color(0xFF475569),
                      altura: 1.5,
                      alineacion: TextAlign.justify,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  List<Widget> _buildStructured(Map<String, dynamic> data) {
    final String introduccion = data['introduccion']?.toString() ?? '';
    final List<dynamic> conceptos = (data['conceptos'] as List?) ?? [];
    final String ejemplo = data['ejemplo']?.toString() ?? '';
    final String consejo = data['consejo']?.toString() ?? '';
    final String resumen = data['resumen']?.toString() ?? '';

    final lista = conceptos
        .map((c) => c is Map ? c : const {})
        .map((c) => (
              titulo: (c['titulo'] ?? '').toString(),
              explicacion: (c['explicacion'] ?? '').toString(),
            ))
        .where((c) => c.titulo.isNotEmpty || c.explicacion.isNotEmpty)
        .toList();

    final bloques = ((data['desarrollo'] as List?) ?? [])
        .map((b) => b is Map ? b : const {})
        .map((b) => (
              subtitulo: (b['subtitulo'] ?? '').toString(),
              texto: (b['texto'] ?? '').toString(),
            ))
        .where((b) => b.texto.isNotEmpty)
        .toList();

    final contenidoConCifras = _hayCifras.hasMatch(introduccion) ||
        bloques.any((b) => _hayCifras.hasMatch(b.texto)) ||
        lista.any((c) => _hayCifras.hasMatch(c.explicacion));

    return [
      _tarjetaConexion(data),
      const SizedBox(height: 26),

      _titulo(Icons.article_outlined, 'Contenido'),
      if (introduccion.isNotEmpty) _parrafo(introduccion),
      for (final b in bloques) ...[
        if (b.subtitulo.isNotEmpty) _subtitulo(b.subtitulo) else const SizedBox(height: 14),
        _parrafo(b.texto),
      ],
      if (contenidoConCifras) ...[
        const SizedBox(height: 12),
        _notaCifras(
          'Los montos y porcentajes son cifras de ejemplo para explicar el tema; no son datos reales ni tu situación.',
          const Color(0xFF2563EB),
        ),
      ],

      if (lista.isNotEmpty) ...[
        const SizedBox(height: 28),
        _titulo(Icons.auto_awesome_rounded, 'Conceptos clave'),
        for (int i = 0; i < lista.length; i++)
          _tarjetaConcepto(i + 1, lista[i].titulo, lista[i].explicacion, esUltimo: i == lista.length - 1),
      ],

      if (ejemplo.isNotEmpty) ...[
        const SizedBox(height: 26),
        _aviso(
          icono: Icons.calculate_outlined,
          titulo: 'Ejemplo práctico',
          texto: ejemplo,
          color: const Color(0xFF059669),
          fondo: const Color(0xFFECFDF5),
          nota: 'Caso hipotético: las cifras son un ejemplo para ilustrar el tema. Cambia los montos por los tuyos para aplicarlo.',
        ),
      ],
      if (consejo.isNotEmpty) ...[
        const SizedBox(height: 14),
        _aviso(
          icono: Icons.lightbulb_outline_rounded,
          titulo: 'Consejo',
          texto: consejo,
          color: const Color(0xFFD97706),
          fondo: const Color(0xFFFFFBEB),
        ),
      ],
      if (resumen.isNotEmpty) ...[
        const SizedBox(height: 14),
        _aviso(
          icono: Icons.bookmark_outline_rounded,
          titulo: 'En resumen',
          texto: resumen,
          color: _primary,
          fondo: const Color(0xFFEBF2FE),
        ),
      ],
      const SizedBox(height: 14),
      _tarjetaSiguiente(data),
    ];
  }

  List<Widget> _buildPlain(String contenido) {
    final parrafos = contenido
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return [
      _tarjetaConexion(null),
      const SizedBox(height: 26),

      // Contenido / Texto Generado por Gemini
      _titulo(Icons.article_outlined, 'Contenido'),
      for (int i = 0; i < parrafos.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        _parrafo(parrafos[i]),
      ],
      const SizedBox(height: 26),

      // 4. Tarjeta Explicativa de Apoyo
      _tarjetaSiguiente(null),
    ];
  }
}