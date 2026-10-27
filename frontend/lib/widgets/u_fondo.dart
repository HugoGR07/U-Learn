import 'dart:math' as math;

import 'package:flutter/material.dart';

class UFondo extends StatefulWidget {
  final double tamano;
  final Color color;

  const UFondo({super.key, this.tamano = 340, this.color = const Color(0xFF1D61E7)});

  @override
  State<UFondo> createState() => _UFondoState();
}

class _UFondoState extends State<UFondo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final Animation<double> _curva = CurvedAnimation(parent: _c, curve: Curves.easeInOutSine);
  late final Animation<double> _opacidad = Tween<double>(begin: 0.75, end: 1).animate(_curva);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  TextStyle _estilo({Color? color, Paint? trazo}) => TextStyle(
        fontSize: widget.tamano,
        fontWeight: FontWeight.w900,
        height: 1.0,
        color: trazo == null ? color : null,
        foreground: trazo,
      );

  Widget _letra() {
    final c = widget.color;
    final t = widget.tamano;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(t * 0.045, t * 0.03),
          child: Text(
            'U',
            style: _estilo(
              trazo: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(1.5, t * 0.006)
                ..color = c.withValues(alpha: 0.10),
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.withValues(alpha: 0.13),
              c.withValues(alpha: 0.06),
              c.withValues(alpha: 0.02),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect),
          child: Text('U', style: _estilo(color: Colors.white)),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: const Alignment(-1, -1),
            end: const Alignment(-0.93, -0.93),
            tileMode: TileMode.repeated,
            colors: [
              c.withValues(alpha: 0.07),
              c.withValues(alpha: 0.07),
              c.withValues(alpha: 0),
              c.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.35, 0.35, 1.0],
          ).createShader(rect),
          child: Text('U', style: _estilo(color: Colors.white)),
        ),
        Text(
          'U',
          style: _estilo(
            trazo: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, t * 0.007)
              ..color = c.withValues(alpha: 0.16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final t = widget.tamano;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _curva,
        builder: (context, child) {
          final v = _curva.value;
          return Transform.translate(
            offset: Offset(6 * v, -14 * v),
            child: Transform.scale(
              scale: 1 + 0.03 * v,
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FadeTransition(
              opacity: _opacidad,
              child: RepaintBoundary(child: _letra()),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    final p = -1.6 + 3.2 * _c.value;
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment(p - 0.5, -1),
                        end: Alignment(p + 0.5, 1),
                        colors: [
                          c.withValues(alpha: 0),
                          c.withValues(alpha: 0.16),
                          c.withValues(alpha: 0),
                        ],
                        stops: const [0.3, 0.5, 0.7],
                      ).createShader(rect),
                      child: child,
                    );
                  },
                  child: Text('U', style: _estilo(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}