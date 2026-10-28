import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class UFondo extends StatefulWidget {
  final double tamano;
  final Color color;

  const UFondo({super.key, this.tamano = 340, this.color = const Color(0xFF1D61E7)});

  @override
  State<UFondo> createState() => _UFondoState();
}

class _UFondoState extends State<UFondo> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Offset _reposo = Offset(-1, 1);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final Animation<double> _curva = CurvedAnimation(parent: _c, curve: Curves.easeInOutSine);
  late final Animation<double> _opacidad = Tween<double>(begin: 0.75, end: 1).animate(_curva);

  late final Ticker _ticker = createTicker(_alTick);
  final ValueNotifier<Offset> _posicion = ValueNotifier(_reposo);
  final ValueNotifier<Offset> _giro = ValueNotifier(Offset.zero);

  StreamSubscription<AccelerometerEvent>? _sensor;
  bool _activo = true;
  bool _enPrimerPlano = true;
  bool _conDatos = false;

  double _rx = 0, _ry = 0;
  Orientation _orientacion = Orientation.portrait;
  bool _horizontalIzquierda = true;
  Offset _objetivo = _reposo;
  Duration _ultimoTick = Duration.zero;

  bool get _soportaSensores =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _activo = TickerMode.of(context);
    _orientacion = MediaQuery.orientationOf(context);
    _actualizarSensor();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    _actualizarSensor();
  }

  void _actualizarSensor() {
    final debeEscuchar = _soportaSensores && _activo && _enPrimerPlano;
    if (debeEscuchar && _sensor == null) {
      _conDatos = false;
      try {
        _sensor = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
          _alMoverse,
          onError: (_) => _detenerSensor(),
          cancelOnError: true,
        );
      } catch (_) {
        _sensor = null;
      }
    } else if (!debeEscuchar && _sensor != null) {
      _detenerSensor();
    }
  }

  void _detenerSensor() {
    _sensor?.cancel();
    _sensor = null;
    if (_ticker.isActive) _ticker.stop();
  }

  void _alMoverse(AccelerometerEvent e) {
    if (!mounted) return;

    if (!_conDatos) {
      _rx = e.x;
      _ry = e.y;
      _conDatos = true;
    } else {
      _rx += (e.x - _rx) * 0.25;
      _ry += (e.y - _ry) * 0.25;
    }

    double gx, gy;
    if (_orientacion == Orientation.landscape) {
      if (_rx > 2.5) {
        _horizontalIzquierda = true;
      } else if (_rx < -2.5) {
        _horizontalIzquierda = false;
      }
      gx = _horizontalIzquierda ? _ry : -_ry;
      gy = _horizontalIzquierda ? _rx : -_rx;
    } else {
      gx = -_rx;
      gy = _ry;
    }

    final nuevo = Offset(
      (gx / 4.5).clamp(-1.0, 1.0),
      (gy / 4.5 - 1).clamp(-1.0, 1.0),
    );

    if ((nuevo - _objetivo).distanceSquared > 0.0004 || (nuevo - _posicion.value).distanceSquared > 0.0004) {
      _objetivo = nuevo;
      if (!_ticker.isActive) {
        _ultimoTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _alTick(Duration transcurrido) {
    final dt = _ultimoTick == Duration.zero
        ? 1 / 60
        : ((transcurrido - _ultimoTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimoTick = transcurrido;

    final actual = _posicion.value;
    final k = 1 - math.exp(-dt * 5.5);
    final siguiente = actual + (_objetivo - actual) * k;
    final velocidad = (siguiente - actual) / (dt == 0 ? 1 / 60 : dt);

    _posicion.value = siguiente;
    _giro.value = Offset(
      (velocidad.dx * 0.18).clamp(-0.35, 0.35),
      (velocidad.dy * 0.18).clamp(-0.35, 0.35),
    );

    if ((_objetivo - siguiente).distanceSquared < 0.000004) {
      _posicion.value = _objetivo;
      _giro.value = Offset.zero;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detenerSensor();
    _ticker.dispose();
    _posicion.dispose();
    _giro.dispose();
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

  Widget _contenido() {
    final c = widget.color;

    return Stack(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamano;
    final contenido = RepaintBoundary(child: _contenido());

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, limites) {
          if (!limites.hasBoundedWidth || !limites.hasBoundedHeight) {
            return AnimatedBuilder(
              animation: _curva,
              builder: (context, child) {
                final v = _curva.value;
                return Transform.translate(offset: Offset(6 * v, -14 * v), child: child);
              },
              child: contenido,
            );
          }

          final minX = -t * 0.06;
          final maxX = math.max(minX, limites.maxWidth - t * 0.66);
          final minY = -t * 0.08;
          final maxY = math.max(minY, limites.maxHeight - t * 0.88);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_curva, _posicion, _giro]),
                  builder: (context, child) {
                    final v = _curva.value;
                    final p = _posicion.value;
                    final g = _giro.value;
                    final x = minX + (p.dx + 1) / 2 * (maxX - minX);
                    final y = minY + (p.dy + 1) / 2 * (maxY - minY);
                    final s = 1 + 0.03 * v;
                    final giro = Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateX(-g.dy)
                      ..rotateY(g.dx);
                    final matriz = Matrix4.translationValues(x + 6 * v + t * 0.33, y - 14 * v + t * 0.5, 0)
                        .multiplied(giro)
                        .multiplied(Matrix4.diagonal3Values(s, s, 1))
                        .multiplied(Matrix4.translationValues(-t * 0.33, -t * 0.5, 0));
                    return Transform(transform: matriz, child: child);
                  },
                  child: contenido,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}