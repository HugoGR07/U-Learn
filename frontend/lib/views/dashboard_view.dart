import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/responsivo.dart';

/// Dashboard con los datos más relevantes de la actividad del usuario.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with SingleTickerProviderStateMixin {
  static const Color _azul = Color(0xFF1D61E7);
  static const Color _verde = Color(0xFF10B981);
  static const Color _rojo = Color(0xFFEF4444);
  static const Color _ambar = Color(0xFFF59E0B);
  static const Color _texto = Color(0xFF0F172A);
  static const Color _suave = Color(0xFF64748B);
  static const Color _gris = Color(0xFFE2E8F0);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await ApiService.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
      if (MediaQuery.disableAnimationsOf(context)) {
        _anim.value = 1;
      } else {
        _anim.forward(from: 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'No pudimos cargar tus estadísticas.';
        _cargando = false;
      });
    }
  }

  // ---------- Lectura segura de datos ----------
  Map<String, dynamic> _mapa(String clave) {
    final v = _datos?[clave];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  double? _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
  double get _umbral => _dbl(_datos?['umbral_aprobatorio']) ?? 60;
  double get _t => Curves.easeOutCubic.transform(_anim.value);

  String _nota(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  Color _colorNota(double? v) {
    if (v == null) return _suave;
    if (v >= _umbral) return _verde;
    return v >= _umbral - 20 ? _ambar : _rojo;
  }

  ({IconData icono, Color color}) _estiloTema(String nombre) {
    final l = nombre.toLowerCase();
    if (l.contains('ahorro')) return (icono: Icons.savings_rounded, color: const Color(0xFFEC4899));
    if (l.contains('tarjeta')) return (icono: Icons.credit_card_rounded, color: const Color(0xFFD97706));
    if (l.contains('presupuesto')) return (icono: Icons.calculate_rounded, color: const Color(0xFF16A34A));
    if (l.contains('deuda') || l.contains('interés')) {
      return (icono: Icons.percent_rounded, color: const Color(0xFF2563EB));
    }
    if (l.contains('personal') || l.contains('finanza')) {
      return (icono: Icons.person_rounded, color: const Color(0xFF0284C7));
    }
    if (l.contains('historial') || l.contains('crédito')) {
      return (icono: Icons.shield_rounded, color: const Color(0xFFE11D48));
    }
    if (l.contains('planeación') || l.contains('planeacion')) {
      return (icono: Icons.track_changes_rounded, color: const Color(0xFFEA580C));
    }
    return (icono: Icons.account_balance_wallet_rounded, color: _azul);
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: RepaintBoundary(child: _encabezado())),
            SliverToBoxAdapter(
              child: AnchoMaximo(
                maximo: 760,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: _cuerpo(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Encabezado con resumen ----------
  Widget _encabezado() {
    final tieneDatos = _datos != null && _int(_mapa('cursos')['tomados']) > 0;

    return EncabezadoAzul(
      grande: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              EncabezadoAzul.boton(
                icon: Icons.arrow_back_ios_new_rounded,
                grande: true,
                size: 22,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mi progreso',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text('Tu actividad en U-Learn', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              EncabezadoAzul.boton(
                icon: Icons.refresh_rounded,
                grande: true,
                size: 24,
                onTap: _cargando ? () {} : _cargar,
              ),
            ],
          ),
          if (tieneDatos) ...[
            const SizedBox(height: 22),
            _resumenEncabezado(),
          ],
        ],
      ),
    );
  }

  Widget _resumenEncabezado() {
    final promedio = _dbl(_mapa('examenes')['promedio']);
    final racha = _int(_datos?['racha_dias']);
    final precision = _dbl(_datos?['precision']);

    final String nivel;
    final IconData iconoNivel;
    if (promedio == null) {
      nivel = 'Presenta tu primer examen';
      iconoNivel = Icons.rocket_launch_rounded;
    } else if (promedio >= 85) {
      nivel = '¡Excelente desempeño!';
      iconoNivel = Icons.emoji_events_rounded;
    } else if (promedio >= _umbral) {
      nivel = 'Vas muy bien';
      iconoNivel = Icons.thumb_up_alt_rounded;
    } else if (promedio >= _umbral - 20) {
      nivel = 'Estás cerca, sigue así';
      iconoNivel = Icons.trending_up_rounded;
    } else {
      nivel = 'Aún puedes mejorar';
      iconoNivel = Icons.school_rounded;
    }

    return Row(
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => SizedBox(
            width: 108,
            height: 108,
            child: CustomPaint(
              painter: _AnilloPainter(
                progreso: ((promedio ?? 0) / 100) * _t,
                color: Colors.white,
                fondo: Colors.white.withValues(alpha: 0.22),
                grosor: 10,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      promedio == null ? '—' : _nota(promedio * _t),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text('promedio', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconoNivel, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nivel,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipHeader(
                    Icons.local_fire_department_rounded,
                    '$racha ${racha == 1 ? 'día' : 'días'}',
                    Colors.orangeAccent,
                  ),
                  _chipHeader(
                    Icons.gps_fixed_rounded,
                    precision == null ? 'Sin aciertos aún' : '${_nota(precision)}% aciertos',
                    Colors.lightGreenAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipHeader(IconData icono, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: EncabezadoAzul.decoracionVidrio.copyWith(borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ---------- Cuerpo ----------
  Widget _cuerpo() {
    if (_cargando && _datos == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: _azul)),
      );
    }
    if (_error != null && _datos == null) return _estadoError();

    final cursos = _mapa('cursos');
    if (_int(cursos['tomados']) == 0) return _estadoVacio();

    final bloques = <Widget>[
      _kpis(cursos),
      _tarjetaEvolucion(),
      _tarjetaProgresoCursos(cursos),
    ];

    return Column(
      children: [
        for (int i = 0; i < bloques.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _aparecer(i, bloques[i]),
        ],
      ],
    );
  }

  // Entrada escalonada de cada bloque
  Widget _aparecer(int indice, Widget hijo) {
    final inicio = (indice * 0.12).clamp(0.0, 0.6);
    final animacion = CurvedAnimation(
      parent: _anim,
      curve: Interval(inicio, (inicio + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, child) => Opacity(
        opacity: animacion.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - animacion.value)), child: child),
      ),
      child: hijo,
    );
  }

  // ---------- Estados ----------
  Widget _estadoError() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 54, color: Color(0xFF94A3B8)),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Ocurrió un error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: _suave),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _cargar,
            style: FilledButton.styleFrom(backgroundColor: _azul),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF2FE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.insights_rounded, size: 42, color: _azul),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aún no tienes actividad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _texto),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea tu primer curso y presenta un examen para ver aquí tus estadísticas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _suave, height: 1.35),
          ),
        ],
      ),
    );
  }

  // ---------- Cursos: 4 números clave ----------
  Widget _kpis(Map<String, dynamic> c) {
    final datos = [
      _Kpi(Icons.menu_book_rounded, 'Cursos tomados', _int(c['tomados']), _azul, destacado: true),
      _Kpi(Icons.timelapse_rounded, 'En curso', _int(c['en_curso']), _ambar),
      _Kpi(Icons.verified_rounded, 'Aprobados', _int(c['aprobados']), _verde),
      _Kpi(Icons.cancel_rounded, 'Reprobados', _int(c['reprobados']), _rojo),
    ];

    return LayoutBuilder(
      builder: (context, caja) {
        const espacio = 12.0;
        final ancho = (caja.maxWidth - espacio) / 2;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final d in datos) SizedBox(width: ancho, child: _tarjetaKpi(d)),
          ],
        );
      },
    );
  }

  Widget _tarjetaKpi(_Kpi d) {
    final fg = d.destacado ? Colors.white : _texto;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: d.destacado
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), _azul, Color(0xFF1E88E5)],
              )
            : null,
        color: d.destacado ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: d.destacado ? null : Border.all(color: _gris),
        boxShadow: [
          BoxShadow(
            color: (d.destacado ? _azul : Colors.black).withValues(alpha: d.destacado ? 0.28 : 0.04),
            blurRadius: d.destacado ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (d.destacado ? Colors.white : d.color).withValues(alpha: d.destacado ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(d.icono, size: 23, color: d.destacado ? Colors.white : d.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => Text(
                    '${(d.valor * _t).round()}',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fg, height: 1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  d.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: d.destacado ? Colors.white70 : _suave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Evolución de calificaciones ----------
  Widget _tarjetaEvolucion() {
    final notas = (_datos?['evolucion_notas'] is List)
        ? (_datos!['evolucion_notas'] as List).map((e) => _dbl(e) ?? 0).toList()
        : <double>[];
    final mejor = _dbl(_mapa('examenes')['mejor']);

    return _tarjeta(
      titulo: 'Evolución de calificaciones',
      icono: Icons.show_chart_rounded,
      trailing: mejor == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _colorNota(mejor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Mejor: ${_nota(mejor)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _colorNota(mejor)),
              ),
            ),
      child: notas.isEmpty
          ? const _Vacio('Presenta un examen para ver cómo evolucionas.')
          : AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LineaPainter(
                    valores: notas,
                    umbral: _umbral,
                    progreso: _t,
                    color: _azul,
                    colorUmbral: _verde,
                  ),
                ),
              ),
            ),
    );
  }

  // ---------- Avance por curso ----------
  Widget _tarjetaProgresoCursos(Map<String, dynamic> cursos) {
    final lista = (cursos['detalle'] is List)
        ? (cursos['detalle'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return _tarjeta(
      titulo: 'Avance por curso',
      icono: Icons.auto_stories_rounded,
      child: Column(
        children: [
          for (int i = 0; i < lista.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _filaCurso(lista[i]),
          ],
        ],
      ),
    );
  }

  Widget _filaCurso(Map<String, dynamic> c) {
    final estilo = _estiloTema('${c['nombre_tema']}');
    final progreso = (_dbl(c['progreso']) ?? 0).clamp(0.0, 1.0);
    final (etiqueta, colorEstado) = switch ('${c['estado']}') {
      'aprobado' => ('Aprobado', _verde),
      'reprobado' => ('Reprobado · promedio ${_nota(_dbl(c['promedio']))}', _rojo),
      _ => progreso == 0 ? ('Sin iniciar', _suave) : ('En curso', _ambar),
    };

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: estilo.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(estilo.icono, color: estilo.color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${c['nombre_tema']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _texto),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => Text(
                      '${(progreso * _t * 100).round()}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: estilo.color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (progreso * _t).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: _gris,
                    valueColor: AlwaysStoppedAnimation(estilo.color),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                etiqueta,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colorEstado),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Contenedor de tarjeta ----------
  Widget _tarjeta({
    required String titulo,
    required IconData icono,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gris),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, size: 18, color: _azul),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _texto),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// =====================================================================
// Modelos auxiliares
// =====================================================================

class _Kpi {
  final IconData icono;
  final String etiqueta;
  final int valor;
  final Color color;
  final bool destacado;
  const _Kpi(this.icono, this.etiqueta, this.valor, this.color, {this.destacado = false});
}

class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

// =====================================================================
// Gráficas dibujadas a mano (sin dependencias externas)
// =====================================================================

/// Anillo de progreso (gauge circular).
class _AnilloPainter extends CustomPainter {
  final double progreso; // 0–1
  final Color color;
  final Color fondo;
  final double grosor;

  _AnilloPainter({required this.progreso, required this.color, required this.fondo, required this.grosor});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = (math.min(size.width, size.height) - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..color = fondo,
    );

    final p = progreso.clamp(0.0, 1.0);
    if (p <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.progreso != progreso || old.color != color || old.fondo != fondo || old.grosor != grosor;
}

/// Gráfica de línea con área degradada y línea de nota aprobatoria.
class _LineaPainter extends CustomPainter {
  final List<double> valores; // 0–100
  final double umbral;
  final double progreso; // 0–1 (animación)
  final Color color;
  final Color colorUmbral;

  _LineaPainter({
    required this.valores,
    required this.umbral,
    required this.progreso,
    required this.color,
    required this.colorUmbral,
  });

  static const double _izq = 30;
  static const double _abajo = 4;
  static const double _arriba = 8;

  void _texto(Canvas canvas, String t, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width, pos.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width - _izq - 6;
    final alto = size.height - _arriba - _abajo;
    double y(double v) => _arriba + alto * (1 - v.clamp(0, 100) / 100);

    // Rejilla y etiquetas del eje Y
    final rejilla = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (final v in [0, 25, 50, 75, 100]) {
      canvas.drawLine(Offset(_izq, y(v.toDouble())), Offset(size.width, y(v.toDouble())), rejilla);
      _texto(canvas, '$v', Offset(_izq - 6, y(v.toDouble())));
    }

    // Línea de nota aprobatoria (punteada)
    final pu = Paint()
      ..color = colorUmbral
      ..strokeWidth = 1.6;
    for (double x = _izq; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y(umbral)), Offset(math.min(x + 5, size.width), y(umbral)), pu);
    }

    if (valores.isEmpty) return;

    final n = valores.length;
    final pasos = n > 1 ? n - 1 : 1;
    final puntos = <Offset>[
      for (int i = 0; i < n; i++) Offset(n > 1 ? _izq + ancho * (i / pasos) : _izq + ancho / 2, y(valores[i])),
    ];

    // Recorte horizontal para animar el trazo de izquierda a derecha
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, _izq + (size.width - _izq) * progreso, size.height));

    // Curva suave (Catmull-Rom → Bézier)
    final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (int i = 0; i < puntos.length - 1; i++) {
      final p0 = i > 0 ? puntos[i - 1] : puntos[i];
      final p1 = puntos[i];
      final p2 = puntos[i + 1];
      final p3 = i + 2 < puntos.length ? puntos[i + 2] : p2;
      linea.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }

    if (puntos.length > 1) {
      final area = Path.from(linea)
        ..lineTo(puntos.last.dx, y(0))
        ..lineTo(puntos.first.dx, y(0))
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
          ).createShader(Rect.fromLTWH(0, _arriba, size.width, alto)),
      );
      canvas.drawPath(
        linea,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }

    // Marcadores (verde si aprobó)
    for (int i = 0; i < puntos.length; i++) {
      canvas.drawCircle(puntos[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(puntos[i], 4.2, Paint()..color = valores[i] >= umbral ? colorUmbral : color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineaPainter old) =>
      old.progreso != progreso || old.valores != valores || old.umbral != umbral;
}
