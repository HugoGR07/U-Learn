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

  List<dynamic> get _preguntas => (widget.examen['preguntas'] as List?) ?? [];
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

          if (selectedOptionIndex < opciones.length) {
            final opcion = opciones[selectedOptionIndex];
            if (opcion is Map && opcion['inciso'] != null) {
              letraSeleccionada = opcion['inciso'].toString();
            } else if (selectedOptionIndex < _letras.length) {
              letraSeleccionada = _letras[selectedOptionIndex];
            }
          }

          respuestasPayload.add({
            'id_pregunta': idPregunta,
            'opcion_seleccionada': letraSeleccionada,
          });
        }
      }

      // Mandamos los datos al backend para guardar calificación
      final Map<String, dynamic> res = await ApiService.completeSectionExam(
        widget.examen['id_examen'] ?? widget.idSeccion,
        respuestasPayload,
      );

      if (!mounted) return;

      // -------------------------------------------------------------------------
      // DECLARACIÓN Y PROCESAMIENTO DE VARIABLES LOCALES
      // -------------------------------------------------------------------------
      List<Map<String, dynamic>> erroresLocales = [];
      List<Map<String, dynamic>> examenCompletoLocal = [];
      int correctasLocales = 0;
      int incorrectasLocales = 0;

      for (int i = 0; i < _preguntas.length; i++) {
        final pregunta = _preguntas[i] as Map<String, dynamic>;
        final enunciado = pregunta['pregunta'] ?? pregunta['enunciado'] ?? 'Sin pregunta';
        final opciones = (pregunta['opciones'] as List?) ?? [];
        
        String letraCorrecta = '';
        String textoCorrecta = '';

        // 1. Buscar si alguna opción está marcada explícitamente como correcta
        for (var op in opciones) {
          if (op is Map) {
            final bool esCorrecta = op['es_correcta'] == true || 
                                   op['esCorrecta'] == true || 
                                   op['correcta'] == true || 
                                   op['is_correct'] == true;
            if (esCorrecta) {
              letraCorrecta = op['inciso']?.toString() ?? op['letra']?.toString() ?? '';
              textoCorrecta = op['texto']?.toString() ?? op['opcion']?.toString() ?? '';
            }
          }
        }
        
        // 2. Si no se marcó en las opciones, buscar en la propiedad general de la pregunta
        if (letraCorrecta.isEmpty) {
          letraCorrecta = pregunta['respuesta_correcta']?.toString() ?? pregunta['correcta']?.toString() ?? '';
        }

        // 3. Si tenemos la letra correcta (ej: "B") pero no el texto, extraerlo del arreglo de opciones
        if (textoCorrecta.isEmpty && letraCorrecta.isNotEmpty) {
          for (var op in opciones) {
            if (op is Map) {
              final incisoOp = (op['inciso']?.toString() ?? '').trim().toUpperCase();
              if (incisoOp == letraCorrecta.trim().toUpperCase()) {
                textoCorrecta = op['texto']?.toString() ?? op['opcion']?.toString() ?? '';
                break;
              }
            }
          }
        }

        // Fallback final por si el texto sigue vacío
        if (textoCorrecta.isEmpty) {
          textoCorrecta = letraCorrecta;
        }

        final int? optIndexUsuario = _respuestasUsuario[i];
        String letraUsuario = '';
        String textoUsuario = 'No respondida';

        if (optIndexUsuario != null && optIndexUsuario < opciones.length) {
          final opUser = opciones[optIndexUsuario];
          if (opUser is Map) {
            letraUsuario = opUser['inciso']?.toString() ?? (optIndexUsuario < _letras.length ? _letras[optIndexUsuario] : '');
            textoUsuario = opUser['texto']?.toString() ?? '';
          } else {
            letraUsuario = optIndexUsuario < _letras.length ? _letras[optIndexUsuario] : '';
            textoUsuario = opUser.toString();
          }
        }

        bool esError = false;
        if (letraCorrecta.isNotEmpty && letraUsuario.isNotEmpty) {
          esError = letraUsuario.trim().toUpperCase() != letraCorrecta.trim().toUpperCase();
        } else {
          esError = optIndexUsuario == null; 
        }

        // Formato limpio con inciso y texto completo (ej: B) Texto de la opción)
        final String respuestaCorrectaFormateada = letraCorrecta.isNotEmpty && !textoCorrecta.startsWith('$letraCorrecta)')
            ? '$letraCorrecta) $textoCorrecta'
            : textoCorrecta;

        final String respuestaUsuarioFormateada = letraUsuario.isNotEmpty && textoUsuario != 'No respondida' && !textoUsuario.startsWith('$letraUsuario)')
            ? '$letraUsuario) $textoUsuario'
            : textoUsuario;

        examenCompletoLocal.add({
          'pregunta': enunciado,
          'es_correcta': !esError,
          'respuesta_usuario': respuestaUsuarioFormateada,
          'respuesta_correcta': respuestaCorrectaFormateada,
        });

        if (esError) {
          incorrectasLocales++;
          erroresLocales.add({
            'pregunta': enunciado,
            'respuesta_usuario': respuestaUsuarioFormateada,
            'respuesta_correcta': respuestaCorrectaFormateada,
          });
        } else {
          correctasLocales++;
        }
      }

      final int total = _preguntas.length;
      final int correctasFinal = (res['resultado']?['correctas'] != null) 
          ? int.tryParse(res['resultado']['correctas'].toString()) ?? correctasLocales 
          : correctasLocales;
          
      final int incorrectasFinal = (res['resultado']?['incorrectas'] != null) 
          ? int.tryParse(res['resultado']['incorrectas'].toString()) ?? incorrectasLocales 
          : incorrectasLocales;

      final double porcentajeCalc = total > 0 ? (correctasFinal / total) * 100 : 0;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultView(
            totalPreguntas: total,
            correctas: correctasFinal,
            incorrectas: incorrectasFinal,
            porcentaje: porcentajeCalc.round(),
            erroresDelExamen: erroresLocales,
            examenCompleto: examenCompletoLocal,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el examen: $e'),
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

    final preguntaActual = _preguntas[_currentQuestionIndex] as Map<String, dynamic>;
    final String enunciado = preguntaActual['pregunta'] ?? preguntaActual['enunciado'] ?? '';
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
                      'Evaluando respuestas...',
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
                          Text(
                            'Pregunta ${_currentQuestionIndex + 1} de ${_preguntas.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: opciones.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final isSelected = selectedOptionIndex == index;
                              final rawOption = opciones[index];

                              String optionText = '';
                              String? inciso;

                              if (rawOption is Map) {
                                optionText = rawOption['texto']?.toString() ?? '';
                                inciso = rawOption['inciso']?.toString();
                              } else {
                                optionText = rawOption.toString();
                              }

                              final letter = (inciso != null && inciso.isNotEmpty)
                                  ? inciso
                                  : (index < _letras.length ? _letras[index] : '${index + 1}');

                              return Material(
                                color: isSelected ? const Color(0xFFEBF2FE) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  onTap: () => _onOptionSelected(index),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF1D61E7) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected ? const Color(0xFF1D61E7) : const Color(0xFFF1F5F9),
                                          ),
                                          child: Center(child: Text(letter, style: TextStyle(color: isSelected ? Colors.white : Colors.black))),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            optionText,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF334155),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: ElevatedButton(
                      onPressed: selectedOptionIndex == null ? null : _nextQuestion,
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
                        _currentQuestionIndex == _preguntas.length - 1 ? 'Finalizar Examen' : 'Siguiente',
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