import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/conexion_service.dart';

enum TipoAlerta { exito, error, aviso, info, sinConexion }

class _EstiloAlerta {
  final IconData icono;
  final Color color;
  final Color fondo;

  const _EstiloAlerta(this.icono, this.color, this.fondo);

  static _EstiloAlerta de(TipoAlerta tipo) {
    switch (tipo) {
      case TipoAlerta.exito:
        return const _EstiloAlerta(Icons.check_circle_rounded, Color(0xFF10B981), Color(0xFFECFDF5));
      case TipoAlerta.error:
        return const _EstiloAlerta(Icons.error_rounded, Color(0xFFEF4444), Color(0xFFFEF2F2));
      case TipoAlerta.aviso:
        return const _EstiloAlerta(Icons.warning_amber_rounded, Color(0xFFF59E0B), Color(0xFFFFFBEB));
      case TipoAlerta.info:
        return const _EstiloAlerta(Icons.info_rounded, Color(0xFF1D61E7), Color(0xFFEBF2FE));
      case TipoAlerta.sinConexion:
        return const _EstiloAlerta(Icons.wifi_off_rounded, Color(0xFF475569), Color(0xFFF1F5F9));
    }
  }
}

class AlertaFlotante {
  static const Color _azul = Color(0xFF1D61E7);
  static final Set<String> _abiertas = {};

  static Future<void> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    TipoAlerta tipo = TipoAlerta.info,
    IconData? icono,
    String textoBoton = 'Aceptar',
    Color? colorBoton,
    VoidCallback? alConfirmar,
    bool cerrarAlTocarFuera = false,
  }) async {
    if (!context.mounted) return;

    if (mensaje == ConexionService.mensajeSinInternet) {
      tipo = TipoAlerta.sinConexion;
      titulo = 'Sin conexión';
      icono = null;
    } else if (ConexionService.esMensajeDeConexion(mensaje)) {
      tipo = TipoAlerta.error;
      titulo = 'Error de conexión';
      icono = null;
    }

    final clave = '$titulo|$mensaje';
    if (_abiertas.contains(clave)) return;
    _abiertas.add(clave);

    if (tipo == TipoAlerta.error || tipo == TipoAlerta.sinConexion) {
      HapticFeedback.mediumImpact();
    } else if (tipo == TipoAlerta.exito) {
      HapticFeedback.lightImpact();
    }

    bool confirmado = false;
    try {
      await _abrir<bool>(
        context,
        cerrarAlTocarFuera: cerrarAlTocarFuera,
        hijo: (cerrar) => _VentanaAlerta(
          tipo: tipo,
          icono: icono,
          titulo: titulo,
          mensaje: mensaje,
          botones: [
            _BotonAlerta.principal(
              texto: textoBoton,
              color: colorBoton ?? _azul,
              onTap: () {
                confirmado = true;
                cerrar(true);
              },
            ),
          ],
        ),
      );
    } finally {
      _abiertas.remove(clave);
    }

    if (confirmado) alConfirmar?.call();
  }

  static Future<bool> confirmar(
    BuildContext context, {
    required String titulo,
    String? mensaje,
    TipoAlerta tipo = TipoAlerta.aviso,
    IconData? icono,
    Color? colorIcono,
    Color? fondoIcono,
    Widget? contenido,
    String textoConfirmar = 'Aceptar',
    String textoCancelar = 'Cancelar',
    Color? colorConfirmar,
    bool botonesEnFila = false,
  }) async {
    if (!context.mounted) return false;

    final resultado = await _abrir<bool>(
      context,
      cerrarAlTocarFuera: true,
      hijo: (cerrar) => _VentanaAlerta(
        tipo: tipo,
        icono: icono,
        colorIcono: colorIcono,
        fondoIcono: fondoIcono,
        titulo: titulo,
        mensaje: mensaje,
        contenido: contenido,
        botonesEnFila: botonesEnFila,
        botones: [
          _BotonAlerta.principal(
            texto: textoConfirmar,
            color: colorConfirmar ?? _azul,
            onTap: () => cerrar(true),
          ),
          _BotonAlerta.secundario(
            texto: textoCancelar,
            onTap: () => cerrar(false),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  static Future<T?> _abrir<T>(
    BuildContext context, {
    required bool cerrarAlTocarFuera,
    required Widget Function(void Function(T valor) cerrar) hijo,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: cerrarAlTocarFuera,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, _, __) {
        void cerrar(T valor) {
          if (Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop(valor);
        }

        return hijo(cerrar);
      },
      transitionBuilder: (context, animation, _, child) {
        final entrada = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final opacidad = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.6, curve: Curves.easeOut),
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: opacidad,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(entrada),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1).animate(entrada),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _BotonAlerta {
  final String texto;
  final Color? color;
  final bool principal;
  final VoidCallback onTap;

  const _BotonAlerta.principal({required this.texto, required this.color, required this.onTap})
      : principal = true;

  const _BotonAlerta.secundario({required this.texto, required this.onTap})
      : principal = false,
        color = null;

  Widget construir() {
    if (principal) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
      ),
    );
  }
}

class _VentanaAlerta extends StatefulWidget {
  final TipoAlerta tipo;
  final IconData? icono;
  final Color? colorIcono;
  final Color? fondoIcono;
  final String titulo;
  final String? mensaje;
  final Widget? contenido;
  final List<_BotonAlerta> botones;
  final bool botonesEnFila;

  const _VentanaAlerta({
    required this.tipo,
    required this.titulo,
    required this.botones,
    this.icono,
    this.colorIcono,
    this.fondoIcono,
    this.mensaje,
    this.contenido,
    this.botonesEnFila = false,
  });

  @override
  State<_VentanaAlerta> createState() => _VentanaAlertaState();
}

class _VentanaAlertaState extends State<_VentanaAlerta> with TickerProviderStateMixin {
  late final AnimationController _icono;
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _icono = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _icono.forward();
      _pulso.repeat();
    });
  }

  @override
  void dispose() {
    _icono.dispose();
    _pulso.dispose();
    super.dispose();
  }

  bool get _sacude => widget.tipo == TipoAlerta.error || widget.tipo == TipoAlerta.sinConexion;

  Widget _construirIcono(double tam) {
    final estilo = _EstiloAlerta.de(widget.tipo);
    final color = widget.colorIcono ?? estilo.color;
    final fondo = widget.fondoIcono ?? estilo.fondo;
    final icono = widget.icono ?? estilo.icono;
    final entrada = CurvedAnimation(parent: _icono, curve: Curves.elasticOut);

    return SizedBox(
      width: tam + 28,
      height: tam + 28,
      child: AnimatedBuilder(
        animation: Listenable.merge([_icono, _pulso]),
        builder: (context, _) {
          final p = _pulso.value;
          final sacudida = _sacude && _icono.value < 1
              ? math.sin(_icono.value * math.pi * 6) * (1 - _icono.value) * 0.35
              : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: ((1 - p) * 0.55 * _icono.value).clamp(0.0, 1.0),
                child: Container(
                  width: tam * (1 + p * 0.45),
                  height: tam * (1 + p * 0.45),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ),
              Transform.scale(
                scale: entrada.value.clamp(0.0, 1.3),
                child: Transform.rotate(
                  angle: sacudida,
                  child: Container(
                    width: tam,
                    height: tam,
                    decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
                    child: Icon(icono, color: color, size: tam * 0.53),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _aparecer(int orden, Widget hijo) {
    final inicio = (0.15 + orden * 0.12).clamp(0.0, 0.8);
    final anim = CurvedAnimation(
      parent: _icono,
      curve: Interval(inicio, (inicio + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      child: hijo,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - anim.value)), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final horizontal = media.orientation == Orientation.landscape;
    final tamIcono = horizontal ? 52.0 : 68.0;
    final espacio = horizontal ? 10.0 : 16.0;

    final botones = widget.botones.map((b) => b.construir()).toList();

    final Widget zonaBotones = widget.botonesEnFila || (horizontal && botones.length > 1)
        ? Row(
            children: [
              for (int i = botones.length - 1; i >= 0; i--) ...[
                Expanded(child: botones[i]),
                if (i > 0) const SizedBox(width: 12),
              ],
            ],
          )
        : Column(
            children: [
              for (int i = 0; i < botones.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                botones[i],
              ],
            ],
          );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + media.viewInsets.bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: horizontal ? 460 : 400),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, horizontal ? 14 : 22, 24, horizontal ? 16 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _construirIcono(tamIcono),
                    SizedBox(height: espacio - 6),
                    _aparecer(
                      0,
                      Text(
                        widget.titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (widget.mensaje != null && widget.mensaje!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _aparecer(
                        1,
                        Text(
                          widget.mensaje!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ),
                    ],
                    if (widget.contenido != null) ...[
                      SizedBox(height: espacio),
                      _aparecer(2, widget.contenido!),
                    ],
                    SizedBox(height: horizontal ? 16 : 24),
                    _aparecer(3, zonaBotones),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}