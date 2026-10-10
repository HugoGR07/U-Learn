import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'result_view.dart';

class ExamView extends StatefulWidget {
  final Map<String, dynamic> examen;
  final int idSeccion;

  const ExamView({
    super.key,
    required this.examen,
    required this.idSeccion,
  });

  @override
  State<ExamView> createState() => _ExamViewState();
}

class _ExamViewState extends State<ExamView> {
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  // Lista con las preguntas pasadas dinámicamente
  List<dynamic> get _preguntas => (widget.examen['preguntas'] as List?) ?? [];

  // Mapeo para guardar la opción seleccionada por pregunta: { índicePregunta: índiceOpcion }
  final Map<int, int> _respuestasUsuario = {};

  final List<String> _letras = ['A', 'B', 'C', 'D', 'E', 'F'];

  void _onOptionSelected(int optionIndex) {
    setState(() {
      _respuestasUsuario[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _preguntas.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _completarExamen();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _completarExamen() async {
    setState(() => _isSubmitting = true);

    try {
      final List<Map<String, dynamic>> respuestasPayload = [];

      for (int i = 0; i < _preguntas.length; i++) {
        final pregunta = _preguntas[i];
        final selectedOptionIndex = _respuestasUsuario[i];

        if (pregunta is Map<String, dynamic> && selectedOptionIndex != null) {
          final idPregunta = pregunta['id_pregunta'] ?? pregunta['id'];
          final opciones = (pregunta['opciones'] as List?) ?? [];

          String letraSeleccionada = '';

          // Intentar obtener el inciso si existe en el JSON de opciones, o calcular la letra por el índice
          if (selectedOptionIndex < opciones.length) {
            final opcion = opciones[selectedOptionIndex];
            if (opcion is Map && opcion['inciso'] != null) {
              letraSeleccionada = opcion['inciso'].toString();
            } else if (selectedOptionIndex < _letras.length) {
              letraSeleccionada = _letras[selectedOptionIndex]; // 'A', 'B', 'C', etc.
            }
          }

          respuestasPayload.add({
            'id_pregunta': idPregunta,
            'opcion_seleccionada': letraSeleccionada,
          });
        }
      }

      final Map<String, dynamic> res = await ApiService.completeSectionExam(
        widget.examen['id_examen'] ?? widget.idSeccion,
        respuestasPayload,
      );

      if (!mounted) return;

      // exam_view.dart (Dentro de _completarExamen)

if (res['success'] == true || res['resultado'] != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('¡Examen completado con éxito!'),
      backgroundColor: Color(0xFF10B981),
    ),
  );

  // 1. Extraemos el objeto 'resultado' que envía Node.js
  final Map<String, dynamic> resultado = 
      (res['resultado'] is Map<String, dynamic>) 
          ? res['resultado'] 
          : res;

  // 2. Leemos las claves EXACTAS que envía el backend
  final int total = int.tryParse(resultado['totalPreguntas']?.toString() ?? '') ?? 0;
  final int buenas = int.tryParse(resultado['correctas']?.toString() ?? '') ?? 0;
  final int malas = int.tryParse(resultado['incorrectas']?.toString() ?? '') ?? 0;
  
  // 3. Leemos la calificación (ej. 80.0) y la redondeamos a entero
  final num califRaw = resultado['calificacion'] ?? 0;
  final int pct = califRaw.round();

  // 4. Navegamos pasando las variables mapeadas a ResultView
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ResultView.fromMap(res),
    ),
  );
} else {
        setState(() => _isSubmitting = false);
        final String errorMessage =
            res['message']?.toString() ?? 'Error al guardar el examen';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar el examen: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_preguntas.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Examen'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Este examen no contiene preguntas disponibles.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          ),
        ),
      );
    }

    final preguntaActual =
        _preguntas[_currentQuestionIndex] as Map<String, dynamic>;
    final String enunciado =
        preguntaActual['pregunta'] ?? preguntaActual['enunciado'] ?? '';
    final List<dynamic> opciones = (preguntaActual['opciones'] as List?) ?? [];
    final int? selectedOptionIndex = _respuestasUsuario[_currentQuestionIndex];

    final double progress = (_currentQuestionIndex + 1) / _preguntas.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isSubmitting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1D61E7)),
                    SizedBox(height: 16),
                    Text(
                      'Enviando respuestas...',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),

                          // 1. Barra Superior con botón Atrás y Título
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Color(0xFF1E293B),
                                    size: 20,
                                  ),
                                  onPressed: _previousQuestion,
                                ),
                              ),
                              Text(
                                widget.examen['titulo'] ?? 'Examen',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 2. Indicador dinámico "Pregunta X de Y"
                          Text(
                            'Pregunta ${_currentQuestionIndex + 1} de ${_preguntas.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Barra de Progreso Dinámica
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF1D61E7),
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // 3. Enunciado Dinámico
                          Text(
                            enunciado,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              height: 1.25,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // 4. Lista Dinámica de Opciones
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: opciones.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final isSelected = selectedOptionIndex == index;
                              final rawOption = opciones[index];

                              String optionText = '';
                              String? inciso;

                              if (rawOption is Map) {
                                optionText =
                                    rawOption['texto']?.toString() ?? '';
                                inciso = rawOption['inciso']?.toString();
                              } else {
                                optionText = rawOption.toString();
                              }

                              final letter = (inciso != null &&
                                      inciso.isNotEmpty)
                                  ? inciso
                                  : (index < _letras.length
                                      ? _letras[index]
                                      : '${index + 1}');

                              return Material(
                                color: isSelected
                                    ? const Color(0xFFEBF2FE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  onTap: () => _onOptionSelected(index),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF1D61E7)
                                            : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Círculo con la letra
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? const Color(0xFF1D61E7)
                                                : const Color(0xFFF1F5F9),
                                          ),
                                          child: Center(
                                            child: Text(
                                              letter,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 16),

                                        // Texto de la opción
                                        Expanded(
                                          child: Text(
                                            optionText,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // 5. Botón Dinámico Siguiente / Finalizar Examen
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    child: ElevatedButton(
                      onPressed: selectedOptionIndex == null
                          ? null
                          : _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xFF1D61E7),
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentQuestionIndex == _preguntas.length - 1
                            ? 'Finalizar Examen'
                            : 'Siguiente',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}