import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'login_view.dart';
import 'register_view.dart';
import '../widgets/responsivo.dart';
import '../widgets/ruta_suave.dart';
import '../widgets/u_fondo.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  // Animación de entrada (se ejecuta una vez al abrir la pantalla)
  late final AnimationController _introController;

  // Animación en bucle (partículas flotando, logo "respirando", fondo)
  late final AnimationController _loopController;

  // Partículas: posición relativa (0–1), tamaño, opacidad, velocidad (entera,
  // para que el bucle sea continuo) y fase
  static const List<_Particle> _particles = [
    _Particle(0.12, 0.12, 8, 0.20, 2, 0.0),
    _Particle(0.22, 0.22, 12, 0.25, 1, 1.2),
    _Particle(0.33, 0.34, 16, 0.30, 1, 2.4),
    _Particle(0.60, 0.64, 14, 0.25, 2, 0.7),
    _Particle(0.70, 0.74, 10, 0.20, 2, 3.1),
    _Particle(0.80, 0.83, 12, 0.25, 1, 4.0),
    _Particle(0.15, 0.76, 14, 0.30, 1, 5.2),
    _Particle(0.85, 0.18, 9, 0.18, 2, 2.0),
    _Particle(0.50, 0.08, 6, 0.22, 3, 3.6),
    _Particle(0.92, 0.48, 18, 0.12, 1, 1.7),
  ];

  // Animación en bucle lenta para los íconos que suben por el fondo
  late final AnimationController _iconController;

  // Íconos de Material (vienen incluidos en Flutter, no requieren internet).
  // x: posición horizontal (0–1), start: punto de arranque vertical (0–1),
  // size, opacidad, speed (vueltas por ciclo, entero), sway: vaivén lateral
  static const List<_FloatingIcon> _icons = [
    _FloatingIcon(Icons.savings_rounded, 0.08, 0.05, 34, 0.12, 1, 18),
    _FloatingIcon(Icons.trending_up_rounded, 0.78, 0.15, 30, 0.10, 2, 14),
    _FloatingIcon(Icons.school_rounded, 0.40, 0.30, 28, 0.09, 1, 20),
    _FloatingIcon(Icons.attach_money_rounded, 0.88, 0.45, 32, 0.12, 1, 12),
    _FloatingIcon(Icons.menu_book_rounded, 0.18, 0.55, 30, 0.10, 2, 16),
    _FloatingIcon(Icons.account_balance_rounded, 0.62, 0.68, 30, 0.09, 1, 18),
    _FloatingIcon(Icons.pie_chart_rounded, 0.30, 0.82, 26, 0.11, 2, 14),
    _FloatingIcon(Icons.lightbulb_rounded, 0.72, 0.92, 26, 0.10, 1, 16),
    _FloatingIcon(Icons.account_balance_wallet_rounded, 0.05, 0.38, 28, 0.09, 1, 12),
    _FloatingIcon(Icons.auto_awesome_rounded, 0.52, 0.12, 24, 0.12, 2, 10),
    _FloatingIcon(Icons.calculate_rounded, 0.90, 0.75, 26, 0.09, 2, 14),
    _FloatingIcon(Icons.credit_card_rounded, 0.45, 0.60, 26, 0.08, 1, 18),
  ];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta la opción de "reducir animaciones" del sistema
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _introController.value = 1;
      _loopController.stop();
      _iconController.stop();
    } else {
      if (!_iconController.isAnimating) _iconController.repeat();
      if (!_introController.isCompleted && !_introController.isAnimating) {
        _introController.forward();
      }
      if (!_loopController.isAnimating) _loopController.repeat();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  // Crea una animación escalonada (inicio/fin en fracción de la intro)
  Animation<double> _interval(double begin, double end,
      {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(
      parent: _introController,
      curve: Interval(begin, end, curve: curve),
    );
  }

  // Envuelve un widget con fade + deslizamiento hacia arriba
  Widget _fadeSlide(Widget child, double begin, double end,
      {double offsetY = 24}) {
    final anim = _interval(begin, end);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, offsetY * (1 - anim.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  void _goTo(Widget page) {
    Navigator.push(context, RutaSuave(page: page));
  }

  @override
  Widget build(BuildContext context) {
    final logoAnim = _interval(0.0, 0.55, curve: Curves.elasticOut);
    final logoFade = _interval(0.0, 0.3);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _loopController,
        builder: (context, child) {
          // Desplazamiento suave del degradado de fondo
          final t = _loopController.value * 2 * math.pi;
          final shift = math.sin(t) * 0.25;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.3 + shift, -1),
                end: Alignment(0.3 - shift, 1),
                colors: const [
                  Color(0xFF0D47A1), // Azul oscuro superior
                  Color(0xFF1565C0), // Azul medio
                  Color(0xFF1E88E5), // Azul claro inferior
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: _interval(0.0, 0.6),
                child: UFondo(
                  tamano: (MediaQuery.sizeOf(context).shortestSide * 0.95).clamp(260.0, 500.0),
                  color: Colors.white,
                ),
              ),
            ),

            // Íconos relacionados que suben lentamente por el fondo
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _interval(0.1, 0.8),
                  child: LayoutBuilder(
                    builder: (context, constraints) => AnimatedBuilder(
                      animation: _iconController,
                      builder: (context, _) => Stack(
                        clipBehavior: Clip.none,
                        children: _icons
                            .map((i) => _buildFloatingIcon(
                                  i,
                                  constraints,
                                  _iconController.value,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Partículas flotantes de fondo
            Positioned.fill(
              child: FadeTransition(
                opacity: _interval(0.0, 0.6),
                child: LayoutBuilder(
                  builder: (context, constraints) => AnimatedBuilder(
                    animation: _loopController,
                    builder: (context, _) => Stack(
                      children: _particles
                          .map((p) => _buildParticle(
                                p,
                                constraints,
                                _loopController.value,
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),

            // Contenido Principal
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth > constraints.maxHeight;
                  return horizontal
                      ? _contenidoHorizontal(logoAnim, logoFade)
                      : _contenidoVertical(constraints, logoAnim, logoFade);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenidoVertical(
    BoxConstraints constraints,
    Animation<double> logoAnim,
    Animation<double> logoFade,
  ) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const SizedBox(height: 16),
                _logoAnimado(logoAnim, logoFade, 120),
                const SizedBox(height: 24),
                ..._textos(),
                const Spacer(flex: 3),
                const SizedBox(height: 24),
                ..._botones(),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenidoHorizontal(Animation<double> logoAnim, Animation<double> logoFade) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        children: [
          Expanded(
            child: CentradoDesplazable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logoAnimado(logoAnim, logoFade, 84),
                  const SizedBox(height: 14),
                  ..._textos(compacto: true),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: CentradoDesplazable(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _botones(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoAnimado(Animation<double> logoAnim, Animation<double> logoFade, double tam) {
    // Logo: aparece con rebote y luego "flota"
    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _loopController]),
      builder: (context, child) {
        final t = _loopController.value * 2 * math.pi;
        final floatY = math.sin(t * 3) * 6;
        final breathe = 1 + math.sin(t * 3) * 0.02;
        return Opacity(
          opacity: logoFade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(
              scale: logoAnim.value * breathe,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: tam,
        height: tam,
        child: FittedBox(child: _buildLogo()),
      ),
    );
  }

  List<Widget> _textos({bool compacto = false}) {
    return [
      _fadeSlide(
        Text(
          'U-Learn',
          style: TextStyle(
            fontSize: compacto ? 30 : 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        0.25,
        0.55,
      ),

      SizedBox(height: compacto ? 10 : 40),

      _fadeSlide(
        Text(
          'Educación Financiera Inteligente',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compacto ? 18 : 20,
            fontWeight: FontWeight.w900,
            color: const Color.fromARGB(255, 255, 251, 12),
          ),
        ),
        0.35,
        0.65,
      ),

      SizedBox(height: compacto ? 8 : 12),

      _fadeSlide(
        const Text(
          'Aprende hoy,\nmejora tu futuro financiero.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            height: 1.35,
            fontWeight: FontWeight.w900,
          ),
        ),
        0.45,
        0.75,
      ),

      SizedBox(height: compacto ? 12 : 20),

      _fadeSlide(
        const Text(
          'By Syncore • Guías & Exámenes con IA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
        0.55,
        0.85,
      ),
    ];
  }

  List<Widget> _botones() {
    return [
      // Botón 1: Iniciar Sesión
      _fadeSlide(
        _PressableScale(
          onTap: () => _goTo(const LoginView()),
          child: Container(
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
        ),
        0.65,
        0.95,
        offsetY: 40,
      ),

      const SizedBox(height: 12),

      // Botón 2: Registrarse
      _fadeSlide(
        _PressableScale(
          onTap: () => _goTo(const RegisterView()),
          child: Container(
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1.8),
            ),
            child: const Text(
              'Registrarse',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        0.72,
        1.0,
        offsetY: 40,
      ),
    ];
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.school_rounded,
              size: 60,
              color: Color(0xFF0D47A1),
            );
          },
        ),
      ),
    );
  }

  // Ícono que sube de abajo hacia arriba, se mece de lado a lado y gira
  // un poco. Aparece/desaparece suavemente en los bordes de la pantalla.
  Widget _buildFloatingIcon(_FloatingIcon i, BoxConstraints c, double loop) {
    // Progreso vertical 0→1 (1 = abajo, 0 = arriba), continuo al reiniciar
    final progress = (i.start - loop * i.speed) % 1.0;
    final travel = c.maxHeight + i.size * 2;
    final top = progress * travel - i.size;

    final angle = loop * 2 * math.pi * i.speed * 3 + i.x * 10;
    final dx = math.sin(angle) * i.sway;
    final rotation = math.sin(angle) * 0.25; // ~14°

    // Desvanecer cerca de los bordes superior e inferior
    final edgeFade = (math.min(progress, 1 - progress) / 0.15).clamp(0.0, 1.0);

    return Positioned(
      left: i.x * c.maxWidth + dx - i.size / 2,
      top: top,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(
          i.icon,
          size: i.size,
          color: Colors.white.withValues(alpha: i.opacity * edgeFade),
        ),
      ),
    );
  }

  // Partícula que flota en vertical/horizontal y parpadea suavemente
  Widget _buildParticle(_Particle p, BoxConstraints c, double loop) {
    final t = loop * 2 * math.pi * p.speed + p.phase;
    final dx = math.cos(t) * 12;
    final dy = math.sin(t * 2) * 18;
    final opacity = (p.opacity * (0.7 + 0.3 * math.sin(t * 3))).clamp(0.0, 1.0);

    return Positioned(
      left: p.x * c.maxWidth + dx,
      top: p.y * c.maxHeight + dy,
      child: Container(
        width: p.size,
        height: p.size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _FloatingIcon {
  final IconData icon;
  final double x;
  final double start;
  final double size;
  final double opacity;
  final int speed;
  final double sway;

  const _FloatingIcon(this.icon, this.x, this.start, this.size, this.opacity,
      this.speed, this.sway);
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final int speed;
  final double phase;

  const _Particle(
      this.x, this.y, this.size, this.opacity, this.speed, this.phase);
}

/// Botón que se encoge ligeramente al presionarlo (feedback táctil)
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}