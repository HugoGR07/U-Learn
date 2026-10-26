import 'dart:math' as math;

import 'package:flutter/material.dart';

class EncabezadoAzul extends StatefulWidget {
  static const double tamBoton = 44;
  static const double altoContenido = 48;
  static const double tamBotonGrande = 50;
  static const double altoContenidoGrande = 58;

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? content;
  final double extraBottom;
  final bool grande;

  const EncabezadoAzul({
    super.key,
    this.title = '',
    this.subtitle,
    this.leading,
    this.trailing,
    this.content,
    this.extraBottom = 0,
    this.grande = false,
  });

  static BoxDecoration get decoracionVidrio => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      );

  static Widget boton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 20,
    bool grande = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: grande ? tamBotonGrande : tamBoton,
        height: grande ? tamBotonGrande : tamBoton,
        decoration: decoracionVidrio,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  @override
  State<EncabezadoAzul> createState() => _EncabezadoAzulState();
}

class _EncabezadoAzulState extends State<EncabezadoAzul>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bubble(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }

  Widget _icon(IconData icon, double phase, double size) {
    final t = _controller.value * 4 * math.pi + phase;
    return Transform.translate(
      offset: Offset(math.cos(t) * 8, math.sin(t * 1.5) * 10),
      child: Transform.rotate(
        angle: math.sin(t) * 0.3,
        child: Transform.scale(
          scale: 1 + math.sin(t * 2) * 0.08,
          child: Icon(icon, size: size, color: Colors.white.withValues(alpha: 0.18)),
        ),
      ),
    );
  }

  Widget _drift(Widget child, double phase, double amount) {
    final t = _controller.value * 2 * math.pi + phase;
    return Transform.translate(
      offset: Offset(math.sin(t) * amount, math.cos(t) * amount * 0.6),
      child: child,
    );
  }

  Widget _shimmer() {
    final v = (_controller.value * 2) % 1.0;
    final p = (v / 0.45).clamp(0.0, 1.0);
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(-1 + p * 2, 0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.4, 0.5, 0.6],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.orientationOf(context) == Orientation.landscape;
    final arriba = horizontal ? 6.0 : (widget.grande ? 16.0 : 12.0);
    final abajo = horizontal ? 14.0 : (widget.grande ? 30.0 : 24.0);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1D61E7),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D61E7).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value * 2 * math.pi;
                  final shift = math.sin(t) * 0.35;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1 + shift, -1),
                        end: Alignment(1 - shift, 1),
                        colors: const [
                          Color(0xFF0D47A1),
                          Color(0xFF1D61E7),
                          Color(0xFF1E88E5),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(top: -40, right: -30, child: _drift(_bubble(140, 0.09), 0, 14)),
                        Positioned(bottom: -50, left: -20, child: _drift(_bubble(110, 0.07), 2.5, 12)),
                        Positioned(top: 10, left: 140, child: _drift(_bubble(36, 0.06), 4.5, 10)),
                        Positioned(bottom: 8, left: 70, child: _icon(Icons.savings_rounded, 0, 26)),
                        Positioned(top: 34, right: 90, child: _icon(Icons.credit_card_rounded, 4.2, 22)),
                        Positioned(bottom: 10, right: 30, child: _icon(Icons.trending_up_rounded, 2.1, 26)),
                        Positioned(top: 6, right: 170, child: _icon(Icons.attach_money_rounded, 1.2, 20)),
                        Positioned.fill(child: _shimmer()),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          RepaintBoundary(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  arriba,
                  20,
                  abajo + widget.extraBottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: widget.grande
                        ? EncabezadoAzul.altoContenidoGrande
                        : EncabezadoAzul.altoContenido,
                  ),
                  child: Center(child: widget.content ?? _defaultRow()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _tamBoton =>
      widget.grande ? EncabezadoAzul.tamBotonGrande : EncabezadoAzul.tamBoton;

  Widget _defaultRow() {
    return Row(
      children: [
        widget.leading ?? SizedBox(width: _tamBoton),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.grande ? 21 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: widget.grande ? 13 : 12, color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        widget.trailing ?? SizedBox(width: _tamBoton),
      ],
    );
  }
}