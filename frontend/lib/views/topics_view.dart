import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import './generation_view.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/ruta_suave.dart';

class TopicsView extends StatefulWidget {
  const TopicsView({super.key});

  @override
  State<TopicsView> createState() => _TopicsViewState();
}

class _TopicsViewState extends State<TopicsView>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF1D61E7);
  static const Color _text = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);

  int? selectedTopicId;
  String selectedTopicName = '';
  int selectedWeeks = 2;
  bool isFetchingTopics = true;
  bool _errorTemas = false;

  List<dynamic> topicsFromDb = [];

  // Etiqueta -> semanas que se envían al backend (duracion_semanas)
  final List<Map<String, dynamic>> durations = const [
    {'label': '1 semana', 'weeks': 1, 'num': '1', 'unit': 'semana', 'secciones': 3, 'temas': 3},
    {'label': '2 semanas', 'weeks': 2, 'num': '2', 'unit': 'semanas', 'secciones': 6, 'temas': 3},
    {'label': '3 semanas', 'weeks': 3, 'num': '3', 'unit': 'semanas', 'secciones': 9, 'temas': 3},
    {'label': '1 mes', 'weeks': 4, 'num': '1', 'unit': 'mes', 'secciones': 12, 'temas': 3},
  ];

  // Brillo que recorre el botón y la opción de tiempo elegida (en bucle)
  late final AnimationController _shimmerController;

  // Movimiento suave de los íconos de cada tema (en bucle)
  late final AnimationController _iconController;

  bool _buttonPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadTopicsFromBackend();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  // 1. Cargar temas desde PostgreSQL
  Future<void> _loadTopicsFromBackend() async {
    if (!isFetchingTopics || _errorTemas) {
      setState(() {
        isFetchingTopics = true;
        _errorTemas = false;
      });
    }
    try {
      final fetchedTopics = await ApiService.getTopics();
      if (!mounted) return;

      setState(() {
        topicsFromDb = fetchedTopics;
        if (topicsFromDb.isNotEmpty) {
          selectedTopicId = topicsFromDb[0]['id_tema'];
          selectedTopicName = topicsFromDb[0]['nombre_tema'] ?? '';
        }
        isFetchingTopics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isFetchingTopics = false;
        _errorTemas = true;
      });
      AlertaFlotante.mostrar(
        context,
        titulo: 'No se pudieron cargar los temas',
        mensaje: ApiService.mensajeDe(e),
        tipo: TipoAlerta.error,
      );
    }
  }

  // Mapeo dinámico de Íconos y Colores
  Map<String, dynamic> _getTopicStyle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ahorro')) {
      return {'icon': Icons.savings_rounded, 'color': const Color(0xFFEC4899)};
    } else if (lower.contains('tarjeta')) {
      return {'icon': Icons.credit_card_rounded, 'color': const Color(0xFFD97706)};
    } else if (lower.contains('presupuesto')) {
      return {'icon': Icons.calculate_rounded, 'color': const Color(0xFF16A34A)};
    } else if (lower.contains('deuda') || lower.contains('interés')) {
      return {'icon': Icons.percent_rounded, 'color': const Color(0xFF2563EB)};
    } else if (lower.contains('personal') || lower.contains('finanza')) {
      return {'icon': Icons.person_rounded, 'color': const Color(0xFF0284C7)};
    } else if (lower.contains('historial') || lower.contains('crédito')) {
      return {'icon': Icons.shield_rounded, 'color': const Color(0xFFE11D48)};
    } else if (lower.contains('planeación') || lower.contains('planeacion')) {
      return {'icon': Icons.track_changes_rounded, 'color': const Color(0xFFEA580C)};
    }
    return {'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF1D61E7)};
  }

  void _select(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
  }

  // 2. Abrir la pantalla de generación con el tema y el tiempo elegidos
  Future<void> _generate() async {
    if (selectedTopicName.isEmpty) {
      AlertaFlotante.mostrar(
        context,
        titulo: 'Elige un tema',
        mensaje: 'Por favor selecciona un tema primero.',
        tipo: TipoAlerta.aviso,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      RutaSuave(
        page: GenerationView(
          selectedTopic: selectedTopicName,
          duracionSemanas: selectedWeeks,
        ),
      ),
    );

    // Si terminó de generar con éxito (result == true), regresa a Cursos
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = context.esHorizontal;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 1. Encabezado azul (se desplaza junto con el contenido)
                  EncabezadoAzul(
                    title: 'Nuevo curso',
                    subtitle: 'Crea tu guía de estudio con IA',
                    grande: true,
                    leading: EncabezadoAzul.boton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      grande: true,
                      size: 22,
                      onTap: () => Navigator.maybePop(context),
                    ),
                  ),
                  isFetchingTopics
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: _primary),
                        )
                      : _errorTemas && topicsFromDb.isEmpty
                          ? _buildErrorTemas()
                          : horizontal
                              ? AnchoMaximo(maximo: 1100, child: _buildBodyHorizontal())
                              : AnchoMaximo(maximo: 760, child: _buildBody()),
                ],
              ),
            ),
          ),
          if (!horizontal || isFetchingTopics || (_errorTemas && topicsFromDb.isEmpty))
            SafeArea(top: false, child: AnchoMaximo(maximo: 760, child: _buildBottomButton())),
        ],
      ),
    );
  }

  Widget _buildErrorTemas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF2FE),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.cloud_off_rounded, color: _primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'No pudimos cargar los temas',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _text),
          ),
          const SizedBox(height: 6),
          const Text(
            'Revisa tu conexión e inténtalo de nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadTopicsFromBackend,
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
    );
  }

  Widget _buildBodyHorizontal() {
    final seguro = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20 + seguro.left, 20, 20 + seguro.right, 16 + seguro.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Qué deseas aprender?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _text),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona el tema que más te interese',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 16),
                _buildTopicsGrid(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿En cuánto tiempo deseas terminarlo?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _text),
                ),
                const SizedBox(height: 14),
                _buildDurationSelector(),
                const SizedBox(height: 20),
                _buildPlanSummary(),
                const SizedBox(height: 20),
                _buildBottomButton(conMargen: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Cuerpo ─────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // 2. Sección: ¿Qué deseas aprender?
          const Text(
            '¿Qué deseas aprender?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona el tema que más te interese',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 20),

          _buildTopicsGrid(),

          const SizedBox(height: 32),

          // 3. Sección: Duración
          const Text(
            '¿En cuánto tiempo deseas terminarlo?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          const SizedBox(height: 16),

          _buildDurationSelector(),

          const SizedBox(height: 32),

          _buildPlanSummary(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Grid de temas dinámico
  Widget _buildTopicsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: topicsFromDb.length,
      itemBuilder: (context, index) {
        final topic = topicsFromDb[index];
        final name = (topic['nombre_tema'] ?? '').toString();
        final isSelected = selectedTopicId == topic['id_tema'];
        final style = _getTopicStyle(name);

        return GestureDetector(
          onTap: () => _select(() {
            selectedTopicId = topic['id_tema'];
            selectedTopicName = name;
          }),
          child: AnimatedScale(
            scale: isSelected ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _primary : _border,
                  width: isSelected ? 2.0 : 1.2,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedScale(
                      scale: isSelected ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: _primary,
                        child: Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTopicIcon(
                          style['icon'] as IconData,
                          style['color'] as Color,
                          index,
                          isSelected,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: _text,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Ícono de tema que flota y se mece suavemente (cada uno desfasado).
  // El seleccionado se mueve un poco más y crece ligeramente.
  Widget _buildTopicIcon(
      IconData icon, Color color, int index, bool isSelected) {
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _iconController,
      builder: (context, child) {
        final t = _iconController.value * 2 * math.pi + index * 0.9;
        final amp = isSelected ? 1.0 : 0.5;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * 3 * amp),
          child: Transform.rotate(
            angle: math.sin(t * 2) * 0.08 * amp,
            child: child,
          ),
        );
      },
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: Icon(icon, color: color, size: 28),
      ),
      ),
    );
  }

  // Duración: selector segmentado con indicador que se desliza
  Widget _buildDurationSelector() {
    final selectedIndex =
        durations.indexWhere((d) => d['weeks'] == selectedWeeks);

    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / durations.length;
              return Stack(
                children: [
                  // Indicador azul que se desliza a la opción elegida
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    left: segmentWidth * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _shimmer(0.25),
                      ),
                    ),
                  ),
                  Row(
                    children: durations.map((d) {
                      final weeks = d['weeks'] as int;
                      final isSelected = selectedWeeks == weeks;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(() => selectedWeeks = weeks),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  style: TextStyle(
                                    fontSize: isSelected ? 21 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : _text,
                                    height: 1.0,
                                  ),
                                  child: Text(d['num'] as String),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected ? Colors.white70 : _muted,
                                  ),
                                  child: Text(d['unit'] as String),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSummary() {
    final plan = durations.firstWhere(
      (d) => d['weeks'] == selectedWeeks,
      orElse: () => durations[1],
    );
    final int secciones = plan['secciones'] as int;
    final int temas = plan['temas'] as int;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(selectedWeeks),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF2FE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu guía incluirá en total:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _planStat(Icons.layers_rounded, '$secciones', 'secciones'),
                const SizedBox(width: 10),
                _planStat(Icons.menu_book_rounded, '${secciones * temas}', 'temas'),
                const SizedBox(width: 10),
                _planStat(Icons.quiz_rounded, '$secciones', 'exámenes'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _planStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: _primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  // Franja de brillo diagonal que cruza su contenedor en bucle
  Widget _shimmer(double intensity) {
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        // Recorre de -1 a 2 en la primera mitad del ciclo, luego pausa
        final t = (_shimmerController.value * 2).clamp(0.0, 1.0);
        return FractionalTranslation(
          translation: Offset(-1 + t * 3, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: intensity),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.3, 0.5, 0.7],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  // ───────────────────────── Botón fijo inferior ─────────────────────────
  Widget _buildBottomButton({bool conMargen = true}) {
    final enabled = !isFetchingTopics && selectedTopicName.isNotEmpty;

    return Padding(
      padding: conMargen ? const EdgeInsets.fromLTRB(20, 8, 20, 16) : EdgeInsets.zero,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _buttonPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _buttonPressed = false) : null,
        onTapCancel: () => setState(() => _buttonPressed = false),
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                _generate();
              }
            : null,
        child: AnimatedScale(
          scale: _buttonPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: _primary.withValues(
                              alpha: _buttonPressed ? 0.2 : 0.35),
                          blurRadius: _buttonPressed ? 8 : 18,
                          offset: Offset(0, _buttonPressed ? 3 : 8),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (enabled) Positioned.fill(child: _shimmer(0.22)),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícono de IA que gira y late suavemente
                          RepaintBoundary(
                            child: AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              final v = _shimmerController.value;
                              final pulse = enabled
                                  ? 1 + 0.12 * (1 - (2 * v - 1).abs())
                                  : 1.0;
                              return Transform.rotate(
                                angle: enabled ? v * 2 * math.pi : 0,
                                child:
                                    Transform.scale(scale: pulse, child: child),
                              );
                            },
                            child: const Icon(Icons.auto_awesome_rounded,
                                size: 20, color: Colors.white),
                          ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Generar mi guía',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: Colors.white),
                        ],
                      ),
                    ),
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