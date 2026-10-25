import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/efectos_animados.dart';
import '../widgets/responsivo.dart';

class FundamentosView extends StatefulWidget {
  final List<Map<String, dynamic>> errores;
  final List<Map<String, dynamic>> examenCompleto;

  const FundamentosView({
    super.key,
    required this.errores,
    this.examenCompleto = const [],
  });

  @override
  State<FundamentosView> createState() => _FundamentosViewState();
}

class _FundamentosViewState extends State<FundamentosView>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1D61E7);
  static const Color _text = Color(0xFF1E293B);
  static const Color _body = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _exam = Color(0xFF4F46E5);

  static const List<String> _mensajesCarga = [
    'Revisando cada una de tus respuestas…',
    'Buscando el concepto clave de cada pregunta…',
    'Preparando explicaciones fáciles de entender…',
  ];

  late final AnimationController _loader;
  Timer? _timerMensajes;
  int _mensaje = 0;

  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _fundamentos;
  String _texto = '';

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _cargar();
  }

  @override
  void dispose() {
    _timerMensajes?.cancel();
    _loader.dispose();
    super.dispose();
  }

  void _iniciarMensajes() {
    _timerMensajes?.cancel();
    _mensaje = 0;
    _timerMensajes = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _mensaje = (_mensaje + 1) % _mensajesCarga.length);
    });
  }

  Future<void> _cargar({bool reintento = false}) async {
    if (reintento) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    _iniciarMensajes();

    try {
      final res = await ApiService.askAiTutorDetallado(
        examenCompleto: widget.examenCompleto,
        errores: widget.errores,
      );
      if (!mounted) return;
      setState(() {
        _fundamentos = res['fundamentos'] as Map<String, dynamic>?;
        _texto = (res['respuesta'] ?? '').toString();
        _cargando = false;
        if (_fundamentos == null && _texto.trim().isEmpty) {
          _error = 'No se pudo generar la retroalimentación en este momento.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = ApiService.mensajeDe(
          e,
          porDefecto: 'No pudimos conectar con el tutor de IA. Inténtalo de nuevo.',
        );
      });
    } finally {
      _timerMensajes?.cancel();
    }
  }

  String _limpiar(dynamic s) => (s ?? '')
      .toString()
      .replaceAll(RegExp(r'#{1,6}\s*'), '')
      .replaceAll('**', '')
      .replaceAll('*', '')
      .replaceAll('---', '')
      .replaceAll('\r\n', '\n')
      .trim();

  Widget _buildCargando() {
    return CentradoDesplazable(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: AnimatedBuilder(
                animation: _loader,
                builder: (context, _) {
                  final double t = _loader.value * 2 * math.pi;
                  final double pulso = 0.5 + 0.5 * math.sin(t * 2);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110 + pulso * 16,
                        height: 110 + pulso * 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primary.withValues(alpha: 0.06 + pulso * 0.05),
                        ),
                      ),
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_primary, _exam],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: 1 + pulso * 0.08,
                          child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 44),
                        ),
                      ),
                      ...List.generate(3, (i) {
                        final double a = t + i * 2 * math.pi / 3;
                        return Transform.translate(
                          offset: Offset(math.cos(a) * 64, math.sin(a) * 64),
                          child: Container(
                            width: 10 - i * 2.0,
                            height: 10 - i * 2.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 1 ? const Color(0xFFF59E0B) : _primary,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'El tutor está analizando tus errores',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _text),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _mensajesCarga[_mensaje],
                key: ValueKey(_mensaje),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return CentradoDesplazable(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flotante(
              amplitud: 5,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 42),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No se pudo obtener la explicación',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _text),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _cargar(reintento: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloqueTexto({
    required IconData icon,
    required Color color,
    required String titulo,
    required String texto,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _text),
              ),
              const SizedBox(height: 4),
              Text(
                texto,
                textAlign: TextAlign.justify,
                style: const TextStyle(fontSize: 14, height: 1.55, color: _body),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaFundamento(int index, Map<String, dynamic> f) {
    final Map<String, dynamic> original =
        index < widget.errores.length ? widget.errores[index] : const {};
    final String concepto = _limpiar(f['concepto']);
    final String pregunta = _limpiar(original['pregunta'] ?? original['texto_pregunta']);
    final String porQue = _limpiar(f['por_que_es_incorrecta']);
    final String explicacion = _limpiar(f['explicacion']);
    final String clave = _limpiar(f['clave']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primary, _exam],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ERROR ${index + 1} DE ${widget.errores.length}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        concepto.isNotEmpty ? concepto : 'Concepto evaluado',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (pregunta.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline_rounded, size: 18, color: _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pregunta,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(fontSize: 13.5, height: 1.45, color: _body, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                RespuestaFila(
                  correcta: false,
                  etiqueta: 'Tu respuesta',
                  texto: _limpiar(original['respuesta_usuario'] ?? 'No respondida'),
                ),
                const SizedBox(height: 8),
                RespuestaFila(
                  correcta: true,
                  etiqueta: 'Respuesta correcta',
                  texto: _limpiar(original['respuesta_correcta']),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Divider(height: 1, color: _border),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (porQue.isNotEmpty) ...[
                  _bloqueTexto(
                    icon: Icons.error_outline_rounded,
                    color: _danger,
                    titulo: '¿Por qué está mal?',
                    texto: porQue,
                  ),
                  const SizedBox(height: 14),
                ],
                if (explicacion.isNotEmpty)
                  _bloqueTexto(
                    icon: Icons.menu_book_rounded,
                    color: _primary,
                    titulo: 'Fundamento teórico',
                    texto: explicacion,
                  ),
              ],
            ),
          ),

          if (clave.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flotante(
                    amplitud: 1.5,
                    rotacion: 0.2,
                    escala: 0.08,
                    fase: index * 1.3,
                    child: const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Idea clave',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          clave,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _contenidoTextoPlano() {
    final parrafos = _texto
        .split(RegExp(r'\n\s*\n'))
        .map(_limpiar)
        .where((p) => p.isNotEmpty)
        .toList();

    return parrafos.asMap().entries.map((e) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: _bloqueTexto(
          icon: Icons.menu_book_rounded,
          color: _primary,
          titulo: e.key == 0 ? 'Explicación' : 'Punto ${e.key + 1}',
          texto: e.value,
        ),
      );
    }).toList();
  }

  Widget _encabezado() {
    final int n = widget.errores.length;
    return EncabezadoAzul(
      title: 'Fundamento teórico',
      subtitle: n == 1 ? '1 error explicado por IA' : '$n errores explicados por IA',
      grande: true,
      leading: EncabezadoAzul.boton(
        icon: Icons.arrow_back_ios_new_rounded,
        grande: true,
        size: 22,
        onTap: () => Navigator.maybePop(context),
      ),
    );
  }

  Widget _buildContenido() {
    final f = _fundamentos;
    final List<Map<String, dynamic>> items = f != null && f['errores'] is List
        ? (f['errores'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];

    return ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        _encabezado(),
        AnchoMaximo(
          maximo: 760,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Explicación por pregunta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lee por qué fallaste y la idea clave a recordar.',
                textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 16),
                if (items.isNotEmpty)
                  ...items.asMap().entries.map((e) => _tarjetaFundamento(e.key, e.value))
                else
                  ..._contenidoTextoPlano(),
                const SizedBox(height: 8),
                BrilloDeslizante(
                  borderRadius: BorderRadius.circular(16),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text(
                      '¡Entendido!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: (_cargando || _error != null)
            ? Column(
                children: [
                  _encabezado(),
                  Expanded(
                    child: _cargando ? _buildCargando() : _buildError(),
                  ),
                ],
              )
            : _buildContenido(),
      ),
    );
  }
}