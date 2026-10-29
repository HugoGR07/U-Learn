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

class _DashboardViewState extends State<DashboardView> {
  static const Color _azul = Color(0xFF2563EB);
  static const Color _verde = Color(0xFF10B981);
  static const Color _rojo = Color(0xFFEF4444);
  static const Color _ambar = Color(0xFFF59E0B);
  static const Color _texto = Color(0xFF0F172A);
  static const Color _suave = Color(0xFF64748B);

  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'No pudimos cargar tus estadísticas.';
        _cargando = false;
      });
    }
  }

  // ---------- Utilidades de lectura segura ----------
  Map<String, dynamic> _mapa(String clave) {
    final v = _datos?[clave];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _lista(String clave) {
    final v = _datos?[clave];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  double? _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');

  String _nota(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  Color _colorNota(double? v) {
    if (v == null) return _suave;
    final umbral = _dbl(_datos?['umbral_aprobatorio']) ?? 60;
    if (v >= umbral) return _verde;
    return v >= umbral - 20 ? _ambar : _rojo;
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
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: EncabezadoAzul(
                  title: 'Mi progreso',
                  subtitle: 'Tu actividad en U-Learn',
                  grande: true,
                  leading: EncabezadoAzul.boton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    grande: true,
                    size: 22,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  trailing: EncabezadoAzul.boton(
                    icon: Icons.refresh_rounded,
                    grande: true,
                    size: 24,
                    onTap: _cargando ? () {} : _cargar,
                  ),
                ),
              ),
            ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Mis cursos'),
        _seccionCursos(cursos),
        const SizedBox(height: 24),
        _titulo('Rendimiento'),
        _seccionRendimiento(),
        const SizedBox(height: 24),
        _titulo('Actividad'),
        _seccionActividad(),
        if (_lista('por_tema').isNotEmpty) ...[
          const SizedBox(height: 24),
          _titulo('Rendimiento por tema'),
          _seccionTemas(),
        ],
        if (_lista('ultimos_examenes').isNotEmpty) ...[
          const SizedBox(height: 24),
          _titulo('Últimos exámenes'),
          _seccionUltimos(),
        ],
      ],
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
      padding: const EdgeInsets.only(top: 60),
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

  // ---------- Secciones ----------
  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _texto),
        ),
      );

  Widget _seccionCursos(Map<String, dynamic> c) {
    return _rejilla([
      _Dato(Icons.menu_book_rounded, 'Cursos tomados', '${_int(c['tomados'])}', _azul),
      _Dato(Icons.timelapse_rounded, 'En curso', '${_int(c['en_curso'])}', _ambar),
      _Dato(Icons.verified_rounded, 'Aprobados', '${_int(c['aprobados'])}', _verde),
      _Dato(Icons.cancel_rounded, 'Reprobados', '${_int(c['reprobados'])}', _rojo),
    ]);
  }

  Widget _seccionRendimiento() {
    final ex = _mapa('examenes');
    final pr = _mapa('preguntas');
    final promedio = _dbl(ex['promedio']);
    final mejor = _dbl(ex['mejor']);
    final precision = _dbl(pr['precision']);

    return Column(
      children: [
        _rejilla([
          _Dato(Icons.analytics_rounded, 'Promedio de exámenes', _nota(promedio),
              _colorNota(promedio)),
          _Dato(Icons.emoji_events_rounded, 'Mejor calificación', _nota(mejor),
              _colorNota(mejor)),
          _Dato(Icons.assignment_turned_in_rounded, 'Exámenes presentados',
              '${_int(ex['presentados'])}', _azul),
          _Dato(Icons.assignment_late_rounded, 'Intentos reprobados',
              '${_int(ex['reprobados'])}', _rojo),
        ]),
        const SizedBox(height: 12),
        _tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Precisión en preguntas',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _texto),
                    ),
                  ),
                  Text(
                    precision == null ? '—' : '${_nota(precision)}%',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorNota(precision)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _barra((precision ?? 0) / 100, _colorNota(precision)),
              const SizedBox(height: 8),
              Text(
                '${_int(pr['correctas'])} correctas de ${_int(pr['respondidas'])} respondidas',
                style: const TextStyle(fontSize: 12, color: _suave),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionActividad() {
    final racha = _int(_datos?['racha_dias']);
    return Column(
      children: [
        _rejilla([
          _Dato(Icons.local_fire_department_rounded, 'Racha actual',
              '$racha ${racha == 1 ? 'día' : 'días'}', const Color(0xFFF97316)),
          _Dato(Icons.event_available_rounded, 'Días activos',
              '${_int(_datos?['dias_activos'])}', _azul),
          _Dato(Icons.task_alt_rounded, 'Secciones completadas',
              '${_int(_datos?['secciones_completadas'])}', _verde),
          _Dato(Icons.hourglass_empty_rounded, 'Cursos sin iniciar',
              '${_int(_mapa('cursos')['sin_iniciar'])}', _suave),
        ]),
        const SizedBox(height: 12),
        _tarjeta(child: _graficaSemanal()),
      ],
    );
  }

  Widget _graficaSemanal() {
    final dias = _lista('actividad_semanal');
    final maximo = dias.fold<int>(1, (m, d) => _int(d['examenes']) > m ? _int(d['examenes']) : m);
    const nombres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exámenes en los últimos 7 días',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _texto),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in dias)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _int(d['examenes']) > 0 ? '${_int(d['examenes'])}' : '',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _azul),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: 22,
                        height: 6 + 62 * (_int(d['examenes']) / maximo),
                        decoration: BoxDecoration(
                          color: _int(d['examenes']) > 0
                              ? _azul
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nombres[(DateTime.tryParse('${d['dia']}')?.weekday ?? 1) - 1],
                        style: const TextStyle(fontSize: 11, color: _suave),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionTemas() {
    final temas = _lista('por_tema');
    return _tarjeta(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${t['nombre_tema']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: _texto),
              ),
            ),
            Text(
              _nota(promedio),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: _colorNota(promedio)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _barra((promedio ?? 0) / 100, _colorNota(promedio)),
      ],
    );
  }

  Widget _seccionUltimos() {
    final lista = _lista('ultimos_examenes');
    return _tarjeta(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < lista.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
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
    final aprobado = color == _verde;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              aprobado ? Icons.check_rounded : Icons.close_rounded,
              color: color,
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
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: _texto),
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
          Text(
            _nota(nota),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime f) {
    final d = DateTime.now().difference(f);
    if (d.inDays == 0 && DateTime.now().day == f.day) return 'hoy';
    if (d.inDays <= 1) return 'ayer';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
  }

  // ---------- Componentes ----------
  Widget _tarjeta({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _barra(double valor, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: const Color(0xFFE2E8F0),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }

  // Rejilla de 2 columnas que se adapta al ancho disponible
  Widget _rejilla(List<_Dato> datos) {
    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 12.0;
        final ancho = (c.maxWidth - espacio) / 2;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final d in datos) SizedBox(width: ancho, child: _tarjetaDato(d)),
          ],
        );
      },
    );
  }

  Widget _tarjetaDato(_Dato d) {
    return _tarjeta(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: d.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d.icono, color: d.color, size: 22),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              d.valor,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: _texto, height: 1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            d.etiqueta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: _suave, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _Dato {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;
  const _Dato(this.icono, this.etiqueta, this.valor, this.color);
}
