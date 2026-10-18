import 'dart:math' as math;

import 'package:flutter/material.dart';

class Flotante extends StatefulWidget {
  final Widget child;

  final double amplitud;

  final double rotacion;

  final double escala;

  final Duration periodo;

  final double fase;

  const Flotante({
    super.key,
    required this.child,
    this.amplitud = 4,
    this.rotacion = 0,
    this.escala = 0,
    this.periodo = const Duration(milliseconds: 3200),
    this.fase = 0,
  });

  @override
  State<Flotante> createState() => _FlotanteState();
}

class _FlotanteState extends State<Flotante> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.periodo)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value * 2 * math.pi + widget.fase;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * widget.amplitud),
          child: Transform.rotate(
            angle: math.sin(t) * widget.rotacion,
            child: Transform.scale(
              scale: 1 + math.cos(t) * widget.escala,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class BrilloDeslizante extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double intensidad;
  final Duration periodo;

  const BrilloDeslizante({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.intensidad = 0.22,
    this.periodo = const Duration(milliseconds: 3200),
  });

  @override
  State<BrilloDeslizante> createState() => _BrilloDeslizanteState();
}

class _BrilloDeslizanteState extends State<BrilloDeslizante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.periodo)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final p = (_c.value / 0.5).clamp(0.0, 1.0);
                  return FractionalTranslation(
                    translation: Offset(-1.2 + p * 2.4, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: widget.intensidad),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RespuestaFila extends StatelessWidget {
  final bool correcta;
  final String etiqueta;
  final String texto;

  const RespuestaFila({
    super.key,
    required this.correcta,
    required this.etiqueta,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = correcta ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color fondo = correcta ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final Color oscuro = correcta ? const Color(0xFF065F46) : const Color(0xFF991B1B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              correcta ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: oscuro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}