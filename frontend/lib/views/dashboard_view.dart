import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/responsivo.dart';

/// Dashboard con los datos generales de actividad del usuario.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with SingleTickerProviderStateMixin {
  static const Color _azul = Color(0xFF1D61E7);
  static const Color _azulClaro = Color(0xFF60A5FA);
  static const Color _verde = Color(0xFF10B981);
  static const Color _rojo = Color(0xFFEF4444);
  static const Color _ambar = Color(0xFFF59E0B);
  static const Color _naranja = Color(0xFFF97316);
  static const Color _texto = Color(0xFF0F172A);
  static const Color _suave = Color(0xFF64748B);
  static const Color _gris = Color(0xFFE2E8F0);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
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

  List<Map<String, dynamic>> _lista(String clave, [Map<String, dynamic>? base]) {
    final v = (base ?? _datos)?[clave];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  double? _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
  double get _umbral => _dbl(_datos?['umbral_aprobatorio']) ?? 60;

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
                    Text(
                      'Tu actividad en U-Learn',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
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
    final ex = _mapa('examenes');
    final promedio = _dbl(ex['promedio']);
    final racha = _int(_datos?['racha_dias']);
    final precision = _dbl(_mapa('preguntas')['precision']);

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
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_anim.value);
            return SizedBox(
              width: 112,
              height: 112,
              child: CustomPaint(
                painter: _AnilloPainter(
                  progreso: ((promedio ?? 0) / 100) * t,
                  color: Colors.white,
                  fondo: Colors.white.withValues(alpha: 0.22),
                  grosor: 10,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        promedio == null ? '—' : _nota(promedio * t),
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
            );
          },
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
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipHeader(Icons.local_fire_department_rounded, '$racha ${racha == 1 ? 'día' : 'días'}', Colors.orangeAccent),
                  _chipHeader(Icons.gps_fixed_rounded, precision == null ? '—' : '${_nota(precision)}% aciertos', Colors.lightGreenAccent),
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

    final secciones = <Widget>[
      _kpis(cursos),
      _tarjetaCursos(cursos),
      _tarjetaEvolucion(),
      _tarjetaActividad(),
      _tarjetaPrecision(),
      if (_lista('detalle', cursos).isNotEmpty) _tarjetaProgresoCursos(cursos),
      if (_lista('por_tema').isNotEmpty) _tarjetaTemas(),
      if (_lista('ultimos_examenes').isNotEmpty) _tarjetaUltimos(),
    ];

    return Column(
      children: [
        for (int i = 0; i < secciones.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _aparecer(i, secciones[i]),
        ],
      ],
    );
  }

  // Entrada escalonada de cada bloque
  Widget _aparecer(int indice, Widget hijo) {
    final inicio = (indice * 0.07).clamp(0.0, 0.6);
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

  // Progreso 0–1 compartido por las gráficas
  double get _t => Curves.easeOutCubic.transform(_anim.value);

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

  // ---------- KPIs ----------
  Widget _kpis(Map<String, dynamic> c) {
    final ex = _mapa('examenes');
    final datos = [
      _Kpi(Icons.menu_book_rounded, 'Cursos tomados', _int(c['tomados']), _azul, destacado: true),
      _Kpi(Icons.timelapse_rounded, 'En curso', _int(c['en_curso']), _ambar),
      _Kpi(Icons.verified_rounded, 'Aprobados', _int(c['aprobados']), _verde),
      _Kpi(Icons.cancel_rounded, 'Reprobados', _int(c['reprobados']), _rojo),
      _Kpi(Icons.assignment_turned_in_rounded, 'Exámenes', _int(ex['presentados']), _azulClaro),
      _Kpi(Icons.task_alt_rounded, 'Secciones listas', _int(_datos?['secciones_completadas']), const Color(0xFF8B5CF6)),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 12.0;
        final ancho = (c.maxWidth - espacio * 2) / 3;
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
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (d.destacado ? Colors.white : d.color).withValues(alpha: d.destacado ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(d.icono, size: 20, color: d.destacado ? Colors.white : d.color),
          ),
          const SizedBox(height: 12),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: d.destacado ? Colors.white70 : _suave,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Dona de estado de cursos ----------
  Widget _tarjetaCursos(Map<String, dynamic> c) {
    final aprobados = _int(c['aprobados']);
    final reprobados = _int(c['reprobados']);
    final sinIniciar = _int(c['sin_iniciar']);
    final enCurso = (_int(c['en_curso']) - sinIniciar).clamp(0, 1 << 30);
    final total = _int(c['tomados']);

    final segmentos = [
      _Segmento('Aprobados', aprobados.toDouble(), _verde),
      _Segmento('En curso', enCurso.toDouble(), _ambar),
      _Segmento('Reprobados', reprobados.toDouble(), _rojo),
      _Segmento('Sin iniciar', sinIniciar.toDouble(), const Color(0xFFCBD5E1)),
    ];

    return _tarjeta(
      titulo: 'Estado de mis cursos',
      icono: Icons.donut_large_rounded,
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => SizedBox(
              width: 128,
              height: 128,
              child: CustomPaint(
                painter: _DonaPainter(segmentos: segmentos, progreso: _t, grosor: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _texto,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 1 ? 'curso' : 'cursos',
                        style: const TextStyle(fontSize: 11.5, color: _suave),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (final s in segmentos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.nombre, style: const TextStyle(fontSize: 13, color: _suave)),
                        ),
                        Text(
                          '${s.valor.toInt()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _texto,
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
    );
  }

  // ---------- Evolución de calificaciones ----------
  Widget _tarjetaEvolucion() {
    final notas = _lista('evolucion_notas').map((e) => _dbl(e['calificacion']) ?? 0).toList();
    final ex = _mapa('examenes');

    return _tarjeta(
      titulo: 'Evolución de calificaciones',
      icono: Icons.show_chart_rounded,
      subtitulo: notas.isEmpty ? null : 'Tus últimos ${notas.length} exámenes',
      child: notas.isEmpty
          ? const _Vacio('Presenta exámenes para ver cómo evolucionas.')
          : Column(
              children: [
                AnimatedBuilder(
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniDato('Mejor', _nota(_dbl(ex['mejor'])), _colorNota(_dbl(ex['mejor']))),
                    _miniDato('Promedio', _nota(_dbl(ex['promedio'])), _colorNota(_dbl(ex['promedio']))),
                    _miniDato('Aprobados', '${_int(ex['aprobados'])}', _verde),
                    _miniDato('Reprobados', '${_int(ex['reprobados'])}', _rojo),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _miniDato(String etiqueta, String valor, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: _suave)),
        ],
      ),
    );
  }

  // ---------- Actividad semanal ----------
  Widget _tarjetaActividad() {
    final dias = _lista('actividad_semanal');
    final maximo = dias.fold<int>(1, (m, d) => _int(d['examenes']) > m ? _int(d['examenes']) : m);
    const nombres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final racha = _int(_datos?['racha_dias']);
    final hoy = DateTime.now();

    return _tarjeta(
      titulo: 'Actividad de la semana',
      icono: Icons.bar_chart_rounded,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _naranja.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, size: 16, color: _naranja),
            const SizedBox(width: 3),
            Text(
              '$racha ${racha == 1 ? 'día' : 'días'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _naranja),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => SizedBox(
              height: 128,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in dias)
                    Expanded(
                      child: _barraDia(
                        cantidad: _int(d['examenes']),
                        maximo: maximo,
                        letra: nombres[(DateTime.tryParse('${d['dia']}')?.weekday ?? 1) - 1],
                        esHoy: DateTime.tryParse('${d['dia']}')?.day == hoy.day,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _dato(Icons.event_available_rounded, '${_int(_datos?['dias_activos'])}', 'días activos', _azul),
              _dato(Icons.assignment_turned_in_rounded, '${dias.fold<int>(0, (s, d) => s + _int(d['examenes']))}',
                  'exámenes en 7 días', _verde),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barraDia({required int cantidad, required int maximo, required String letra, required bool esHoy}) {
    final alto = 8 + 72 * (cantidad / maximo) * _t;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 16,
          child: cantidad > 0
              ? Text('$cantidad', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _azul))
              : null,
        ),
        const SizedBox(height: 3),
        Container(
          width: 24,
          height: alto,
          decoration: BoxDecoration(
            gradient: cantidad > 0
                ? const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [_azul, _azulClaro],
                  )
                : null,
            color: cantidad > 0 ? null : _gris,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: esHoy ? _azul : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            letra,
            style: TextStyle(
              fontSize: 11,
              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
              color: esHoy ? Colors.white : _suave,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dato(IconData icono, String valor, String etiqueta, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _texto, height: 1.1)),
                Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _suave)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Precisión (aciertos vs errores) ----------
  Widget _tarjetaPrecision() {
    final pr = _mapa('preguntas');
    final total = _int(pr['respondidas']);
    final correctas = _int(pr['correctas']);
    final incorrectas = total - correctas;
    final precision = _dbl(pr['precision']);

    return _tarjeta(
      titulo: 'Precisión en preguntas',
      icono: Icons.gps_fixed_rounded,
      child: total == 0
          ? const _Vacio('Aún no has respondido preguntas.')
          : Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_nota(precision == null ? null : precision * _t)}%',
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: _colorNota(precision), height: 1),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('de aciertos', style: TextStyle(fontSize: 13, color: _suave)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          Expanded(
                            flex: math.max(1, (correctas * _t * 1000).round()),
                            child: Container(color: _verde),
                          ),
                          Expanded(
                            flex: math.max(1, (incorrectas * 1000).round()),
                            child: Container(color: _rojo.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _leyenda(_verde, '$correctas correctas'),
                    const Spacer(),
                    _leyenda(_rojo, '$incorrectas incorrectas'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12.5, color: _suave)),
      ],
    );
  }

  // ---------- Avance por curso ----------
  Widget _tarjetaProgresoCursos(Map<String, dynamic> cursos) {
    final lista = _lista('detalle', cursos);
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
    final estado = '${c['estado']}';
    final (etiqueta, colorEstado) = switch (estado) {
      'aprobado' => ('Aprobado', _verde),
      'reprobado' => ('Reprobado', _rojo),
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
                  Text(
                    '${(progreso * _t * 100).round()}%',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: estilo.color),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => _barra(progreso * _t, estilo.color),
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

  // ---------- Rendimiento por tema ----------
  Widget _tarjetaTemas() {
    final temas = _lista('por_tema');
    return _tarjeta(
      titulo: 'Rendimiento por tema',
      icono: Icons.pie_chart_rounded,
      subtitulo: 'La marca indica la nota aprobatoria (${_nota(_umbral)})',
      child: Column(
        children: [
          for (int i = 0; i < temas.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _filaTema(temas[i]),
          ],
        ],
      ),
    );
  }

  Widget _filaTema(Map<String, dynamic> t) {
    final promedio = _dbl(t['promedio']);
    final color = _colorNota(promedio);
    final estilo = _estiloTema('${t['nombre_tema']}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(estilo.icono, size: 17, color: estilo.color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${t['nombre_tema']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _texto),
              ),
            ),
            Text(
              _nota(promedio),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 7),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => LayoutBuilder(
            builder: (context, c) => Stack(
              clipBehavior: Clip.none,
              children: [
                _barra(((promedio ?? 0) / 100) * _t, color, alto: 10),
                Positioned(
                  left: c.maxWidth * (_umbral / 100) - 1,
                  top: -3,
                  child: Container(width: 2, height: 16, color: _texto.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Últimos exámenes ----------
  Widget _tarjetaUltimos() {
    final lista = _lista('ultimos_examenes');
    return _tarjeta(
      titulo: 'Últimos exámenes',
      icono: Icons.history_rounded,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          for (int i = 0; i < lista.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _filaExamen(lista[i]),
          ],
        ],
      ),
    );
  }

  Widget _filaExamen(Map<String, dynamic> e) {
    final nota = _dbl(e['calificacion']);
    final color = _colorNota(nota);
    final fecha = DateTime.tryParse('${e['fecha']}')?.toLocal();
    final aprobado = (nota ?? 0) >= _umbral;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CustomPaint(
              painter: _AnilloPainter(
                progreso: ((nota ?? 0) / 100) * _t,
                color: color,
                fondo: color.withValues(alpha: 0.15),
                grosor: 5,
              ),
              child: Center(
                child: Icon(
                  aprobado ? Icons.check_rounded : Icons.close_rounded,
                  size: 20,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e['seccion']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _texto),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e['nombre_tema']} · intento ${_int(e['numero_intento'])}'
                  '${fecha == null ? '' : ' · ${_fecha(fecha)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _suave),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_nota(nota), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  String _fecha(DateTime f) {
    final ahora = DateTime.now();
    final dias = DateTime(ahora.year, ahora.month, ahora.day).difference(DateTime(f.year, f.month, f.day)).inDays;
    if (dias == 0) return 'hoy';
    if (dias == 1) return 'ayer';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
  }

  // ---------- Componentes comunes ----------
  Widget _tarjeta({
    required String titulo,
    required IconData icono,
    required Widget child,
    String? subtitulo,
    Widget? trailing,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
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
          if (subtitulo != null) ...[
            const SizedBox(height: 6),
            Text(subtitulo, style: const TextStyle(fontSize: 12, color: _suave)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _barra(double valor, Color color, {double alto = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        minHeight: alto,
        backgroundColor: _gris,
        valueColor: AlwaysStoppedAnimation(color),
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

class _Segmento {
  final String nombre;
  final double valor;
  final Color color;
  const _Segmento(this.nombre, this.valor, this.color);
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

    final pincelFondo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = fondo;
    canvas.drawCircle(centro, radio, pincelFondo);

    final p = progreso.clamp(0.0, 1.0);
    if (p <= 0) return;
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * p, false, pincel);
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.progreso != progreso || old.color != color || old.fondo != fondo || old.grosor != grosor;
}

/// Gráfica de dona con segmentos de colores.
class _DonaPainter extends CustomPainter {
  final List<_Segmento> segmentos;
  final double progreso; // 0–1 (animación)
  final double grosor;

  _DonaPainter({required this.segmentos, required this.progreso, required this.grosor});

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
        ..color = const Color(0xFFE2E8F0),
    );

    final total = segmentos.fold<double>(0, (s, e) => s + e.valor);
    if (total <= 0) return;

    final activos = segmentos.where((s) => s.valor > 0).length;
    final hueco = activos > 1 ? 0.05 : 0.0; // separación entre segmentos
    final barrido = 2 * math.pi * progreso;
    double inicio = -math.pi / 2;
    double acumulado = 0;

    for (final s in segmentos) {
      if (s.valor <= 0) continue;
      final angulo = (s.valor / total) * 2 * math.pi;
      final visible = math.max(0.0, math.min(angulo, barrido - acumulado));
      acumulado += angulo;
      if (visible <= 0) continue;

      final pincel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.butt
        ..color = s.color;
      final largo = math.max(0.0, visible - hueco);
      canvas.drawArc(rect, inicio + hueco / 2, largo, false, pincel);
      inicio += angulo;
    }
  }

  @override
  bool shouldRepaint(_DonaPainter old) => old.progreso != progreso || old.segmentos != segmentos;
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

  void _texto(Canvas canvas, String t, Offset pos, {Color c = const Color(0xFF94A3B8)}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 10.5, color: c)),
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

    // Puntos
    final n = valores.length;
    final pasos = n > 1 ? n - 1 : 1;
    final puntos = <Offset>[
      for (int i = 0; i < n; i++)
        Offset(n > 1 ? _izq + ancho * (i / pasos) : _izq + ancho / 2, y(valores[i])),
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
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      linea.cubicTo(
        c1.dx,
        c1.dy,
        c2.dx,
        c2.dy,
        p2.dx,
        p2.dy,
      );
    }

    // Área bajo la curva
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

    // Marcadores
    for (int i = 0; i < puntos.length; i++) {
      final aprobado = valores[i] >= umbral;
      canvas.drawCircle(puntos[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(puntos[i], 4.2, Paint()..color = aprobado ? colorUmbral : color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineaPainter old) =>
      old.progreso != progreso || old.valores != valores || old.umbral != umbral;
}
