import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GenerationView extends StatefulWidget {
  final String selectedTopic;
  final String nivel;
  final int duracionSemanas;

  const GenerationView({
    super.key,
    required this.selectedTopic,
    this.nivel = 'Intermedio',
    this.duracionSemanas = 4,
  });

  @override
  State<GenerationView> createState() => _GenerationgGuideViewState();
}

class _GenerationgGuideViewState extends State<GenerationView> {
  double _progress = 0.0;
  Timer? _timer;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startGeneratingCourse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Inicia el temporizador de progreso visual y dispara la petición al backend en paralelo
  void _startGeneratingCourse() {
    // 1. Simulación progresiva del % para feedback visual del usuario
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;

      setState(() {
        if (_progress < 0.90) {
          _progress += 0.03; // Avanza fluidamente hasta el 90%
        }
      });
    });

    // 2. Ejecución real de la API Node.js / Gemini
    _callGenerateApi();
  }

  Future<void> _callGenerateApi() async {
    try {
      final response = await ApiService.generateCourse(
        widget.selectedTopic,
        nivel: widget.nivel,
        duracionSemanas: widget.duracionSemanas,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Al completar con éxito, aceleramos la barra al 100%
        _timer?.cancel();
        setState(() => _progress = 1.0);

        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          // Cierra la pantalla de carga y vuelve a Cursos
          Navigator.pop(context, true);
        }
      } else {
        _handleError(response['message'] ?? 'No se pudo generar la guía de estudio');
      }
    } catch (e) {
      _handleError('Ocurrió un error inesperado al conectar con el servidor');
    }
  }

  void _handleError(String message) {
    _timer?.cancel();
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int percentage = (_progress * 100).toInt();

    // Determinamos qué pasos marcar como completados
    final bool step1 = _progress >= 0.25;
    final bool step2 = _progress >= 0.50;
    final bool step3 = _progress >= 0.75;
    final bool step4 = _progress >= 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 1. Logo U-Learn
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.school_rounded,
                          size: 38,
                          color: Color(0xFF1D61E7),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // 2. Título Principal
                const Text(
                  'Generando tu guía\npersonalizada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtítulo
                Text(
                  'La IA está creando un plan de estudio\nespecial sobre "${widget.selectedTopic}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 40),

                // 3. Indicador Porcentaje Circular Animado
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 14,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1D61E7),
                          ),
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D61E7),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // 4. Lista Dinámica de Pasos
                Column(
                  children: [
                    _buildStepItem(
                      title: 'Analizando el curso seleccionado',
                      isCompleted: step1,
                      isDotted: !step1 && _progress < 0.25,
                    ),
                    const SizedBox(height: 16),
                    _buildStepItem(
                      title: 'Organizando el contenido',
                      isCompleted: step2,
                      isDotted: !step2 && step1,
                    ),
                    const SizedBox(height: 16),
                    _buildStepItem(
                      title: 'Generando lecciones con IA',
                      isCompleted: step3,
                      isDotted: !step3 && step2,
                    ),
                    const SizedBox(height: 16),
                    _buildStepItem(
                      title: 'Preparando ejercicios y examen',
                      isCompleted: step4,
                      isDotted: !step4 && step3,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // 5. Porcentaje y Barra de Progreso Inferior
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D61E7),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF1D61E7),
                    ),
                  ),
                ),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = '';
                        _progress = 0.0;
                      });
                      _startGeneratingCourse();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D61E7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String title,
    bool isCompleted = false,
    bool isDotted = false,
  }) {
    Widget iconWidget;

    if (isCompleted) {
      iconWidget = const Icon(
        Icons.check_rounded,
        color: Color(0xFF10B981),
        size: 20,
      );
    } else if (isDotted) {
      iconWidget = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF1D61E7),
        ),
      );
    } else {
      iconWidget = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 2,
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCompleted || isDotted ? FontWeight.w600 : FontWeight.w500,
              color: isCompleted || isDotted ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}