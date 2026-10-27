// lib/views/exam_view.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'result_view.dart';
import '../services/notification_service.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/componentes_guia.dart';
import '../widgets/efectos_animados.dart';
import '../widgets/ruta_suave.dart';

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

  static const Color _primary = Color(0xFF1D61E7);
  static const Color _exam = Color(0xFF4F46E5);
  static const Color _text = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);

  bool _haciaAdelante = true;

  int get _maxDisponible {
    int i = 0;
    while (i < _preguntas.length - 1 && _respuestasUsuario.containsKey(i)) {
      i++;
    }
    return i;
  }

  void _irA(int indice) {
    if (indice == _currentQuestionIndex || indice > _maxDisponible) return;
    setState(() {
      _haciaAdelante = indice > _currentQuestionIndex;
      _currentQuestionIndex = indice;
    });
  }

  Future<void> _salir() async {
    if (_respuestasUsuario.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final salir = await AlertaFlotante.confirmar(
      context,
      titulo: '¿Salir del examen?',
      mensaje: 'Las respuestas de este intento no se guardarán.',
      tipo: TipoAlerta.aviso,
      icono: Icons.logout_rounded,
      textoConfirmar: 'Salir',
      textoCancelar: 'Seguir respondiendo',
      colorConfirmar: const Color(0xFFF59E0B),
    );
    if (salir && mounted) Navigator.pop(context);
  }

  void _onOptionSelected(int optionIndex) {
    setState(() {
      _respuestasUsuario[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _preguntas.length - 1) {
      setState(() {
        _haciaAdelante = true;
        _currentQuestionIndex++;
      });
    } else {
      _completarExamen();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _haciaAdelante = false;
        _currentQuestionIndex--;
      });
    } else {
      _salir();
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

      // PROCESAMIENTO LOCAL DE RESULTADOS CON TEXTO Y CONCEPTO COMPLETO
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

        for (var op in opciones) {
          if (op is Map) {
            final bool esCorrecta = op['es_correcta'] == true || 
                                   op['esCorrecta'] == true || 
                                   op['correcta'] == true || 
                                   op['is_correct'] == true;
            if (esCorrecta) {
              letraCorrecta = op['inciso']?.toString().trim().toUpperCase() ?? '';
              textoCorrecta = op['texto']?.toString().trim() ?? op['opcion']?.toString().trim() ?? '';
            }
          }
        }
        
        if (letraCorrecta.isEmpty) {
          letraCorrecta = pregunta['respuesta_correcta']?.toString().trim().toUpperCase() ?? 
                          pregunta['correcta']?.toString().trim().toUpperCase() ?? '';
        }

        if (textoCorrecta.isEmpty && letraCorrecta.isNotEmpty) {
          for (var op in opciones) {
            if (op is Map) {
              final incisoOp = (op['inciso']?.toString() ?? '').trim().toUpperCase();
              if (incisoOp == letraCorrecta) {
                textoCorrecta = op['texto']?.toString().trim() ?? op['opcion']?.toString().trim() ?? '';
                break;
              }
            }
          }
        }

        final int? optIndexUsuario = _respuestasUsuario[i];
        String letraUsuario = '';
        String textoUsuario = '';

        if (optIndexUsuario != null && optIndexUsuario < opciones.length) {
          final opUser = opciones[optIndexUsuario];
          if (opUser is Map) {
            letraUsuario = opUser['inciso']?.toString().trim().toUpperCase() ?? 
                           (optIndexUsuario < _letras.length ? _letras[optIndexUsuario] : '');
            textoUsuario = opUser['texto']?.toString().trim() ?? opUser['opcion']?.toString().trim() ?? '';
          } else {
            letraUsuario = optIndexUsuario < _letras.length ? _letras[optIndexUsuario] : '';
            textoUsuario = opUser.toString().trim();
          }
        }

        bool esError = false;
        if (letraCorrecta.isNotEmpty && letraUsuario.isNotEmpty) {
          esError = letraUsuario != letraCorrecta;
        } else {
          esError = optIndexUsuario == null; 
        }

        // Formato unificado: "Inciso) Texto completo del concepto"
        final String respuestaCorrectaFormateada = letraCorrecta.isNotEmpty && textoCorrecta.isNotEmpty
            ? '$letraCorrecta) $textoCorrecta'
            : (textoCorrecta.isNotEmpty ? textoCorrecta : (letraCorrecta.isNotEmpty ? letraCorrecta : 'No especificada'));

        final String respuestaUsuarioFormateada = letraUsuario.isNotEmpty && textoUsuario.isNotEmpty
            ? '$letraUsuario) $textoUsuario'
            : (textoUsuario.isNotEmpty ? textoUsuario : (letraUsuario.isNotEmpty ? letraUsuario : 'No respondida'));

        examenCompletoLocal.add({
          'pregunta': enunciado,
          'es_correcta': !esError,
          'respuesta_usuario': respuestaUsuarioFormateada,
          'respuesta_correcta': respuestaCorrectaFormateada,
        });

        if (esError) {
          incorrectasLocales++;
          erroresLocales.add({
            'id_pregunta': pregunta['id_pregunta'] ?? pregunta['id'],
            'pregunta': enunciado,
            'respuesta_usuario': respuestaUsuarioFormateada,
            'respuesta_correcta': respuestaCorrectaFormateada,
          });
        } else {
          correctasLocales++;
        }
      }

      if (res['success'] == true || res['resultado'] != null) {
        final Map<String, dynamic> resultado = 
            (res['resultado'] is Map<String, dynamic>) 
                ? res['resultado'] 
                : res;

        final int total = int.tryParse(resultado['totalPreguntas']?.toString() ?? '') ?? _preguntas.length;
        final int buenas = int.tryParse(resultado['correctas']?.toString() ?? '') ?? correctasLocales;
        final int malas = int.tryParse(resultado['incorrectas']?.toString() ?? '') ?? incorrectasLocales;
        
        final num califRaw = resultado['calificacion'] ?? ((buenas / total) * 100);
        final int pct = califRaw.round();

        final numSeccion = widget.examen['numero_seccion'];
        final tituloSeccion = (widget.examen['titulo_seccion'] ?? '').toString().trim();
        final nombreGuia = (widget.examen['nombre_guia'] ?? '').toString().trim();
        final cual = [
          if (numSeccion != null) 'Sección $numSeccion',
          if (tituloSeccion.isNotEmpty) '«$tituloSeccion»',
        ].join(' ');
        final donde = [
          if (cual.isNotEmpty) cual,
          if (nombreGuia.isNotEmpty) 'de «$nombreGuia»',
        ].join(' ');
        final aprobado = pct >= 60;
        NotificationService.showProgress(
          aprobado ? '¡Aprobaste el examen! 🏆' : 'Examen terminado 📝',
          '${donde.isEmpty ? 'Examen' : donde}: Acertaste $buenas/$total preguntas ($pct%).'
          '${aprobado ? '' : ' Repasa los temas y vuelve a intentarlo.'}',
        );

        Navigator.pushReplacement(
          context,
          RutaSuave(
            page: ResultView(
              totalPreguntas: total,
              correctas: buenas,
              incorrectas: malas,
              porcentaje: pct,
              erroresDelExamen: erroresLocales,
              examenCompleto: examenCompletoLocal,
            ),
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        final String errorMessage =
            res['message']?.toString() ?? 'No se pudo enviar tu examen. Inténtalo de nuevo.';

        AlertaFlotante.mostrar(
          context,
          titulo: 'No se pudo enviar el examen',
          mensaje: errorMessage,
          tipo: TipoAlerta.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AlertaFlotante.mostrar(
        context,
        titulo: 'No se pudo enviar el examen',
        mensaje: 'Tus respuestas no se enviaron. Inténtalo de nuevo.',
        tipo: TipoAlerta.error,
      );
    }
  }

  Widget _estadoCentral({
    required IconData icono,
    required String titulo,
    required String mensaje,
    Widget? accion,
  }) {
    return CentradoDesplazable(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flotante(
            amplitud: 6,
            escala: 0.05,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primary, _exam],
                ),
                boxShadow: [
                  BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10)),
                ],
              ),
              child: Icon(icono, color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _text),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted, height: 1.4),
          ),
          if (accion != null) ...[const SizedBox(height: 24), accion],
        ],
      ),
    );
  }

  Widget _barraSuperior(bool horizontal) {
    final total = _preguntas.length;
    final respondidas = _respuestasUsuario.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, horizontal ? 4 : 10, 20, horizontal ? 6 : 12),
      child: AnchoMaximo(
        maximo: 800,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _text),
                  onPressed: _salir,
                ),
                Expanded(
                  child: Text(
                    widget.examen['titulo']?.toString() ?? 'Examen',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _text),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_primary, _exam]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '$respondidas/$total',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: List.generate(total, (i) {
                  final actual = i == _currentQuestionIndex;
                  final respondida = _respuestasUsuario.containsKey(i);
                  final color = actual
                      ? _exam
                      : respondida
                          ? _primary
                          : const Color(0xFFE2E8F0);
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _irA(i),
                      child: Padding(
                        padding: EdgeInsets.only(right: i == total - 1 ? 0 : 4, top: 6, bottom: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          height: actual ? 8 : 6,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: actual
                                ? [BoxShadow(color: _exam.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPregunta(String enunciado, bool horizontal) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _primary.withValues(alpha: 0.10), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(Icons.quiz_rounded, size: 110, color: _primary.withValues(alpha: 0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 6,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_primary, _exam])),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, horizontal ? 14 : 18, 20, horizontal ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flotante(
                          amplitud: 2.5,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.psychology_alt_rounded, color: _exam, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'PREGUNTA ${_currentQuestionIndex + 1} DE ${_preguntas.length}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: _exam,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextoConDinero(
                      enunciado,
                      acento: _exam,
                      tamano: horizontal ? 18 : 20,
                      color: _text,
                      peso: FontWeight.w700,
                      altura: 1.3,
                      alineacion: TextAlign.justify,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opcion(int index, dynamic rawOption, bool seleccionada) {
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

    return AnimatedScale(
      scale: seleccionada ? 1.015 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: seleccionada
              ? const LinearGradient(colors: [Color(0xFFEBF2FE), Color(0xFFEEF2FF)])
              : null,
          color: seleccionada ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seleccionada ? _primary : const Color(0xFFE2E8F0),
            width: seleccionada ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (seleccionada ? _primary : const Color(0xFF0F172A)).withValues(alpha: seleccionada ? 0.16 : 0.04),
              blurRadius: seleccionada ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _onOptionSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: seleccionada ? const LinearGradient(colors: [_primary, _exam]) : null,
                      color: seleccionada ? null : const Color(0xFFF1F5F9),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: seleccionada ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextoConDinero(
                      optionText,
                      acento: _primary,
                      tamano: 15,
                      color: seleccionada ? _text : const Color(0xFF334155),
                      peso: FontWeight.w600,
                      altura: 1.35,
                      alineacion: TextAlign.justify,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: seleccionada ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: const Icon(Icons.check_circle_rounded, color: _primary, size: 24),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraInferior(bool horizontal, int? seleccion) {
    final ultima = _currentQuestionIndex == _preguntas.length - 1;
    final altura = horizontal ? 46.0 : 52.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        horizontal ? 8 : 12,
        20,
        (horizontal ? 8 : 16) + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: AnchoMaximo(
        maximo: 800,
        child: Row(
          children: [
            if (_currentQuestionIndex > 0) ...[
              SizedBox(
                width: altura,
                height: altura,
                child: OutlinedButton(
                  onPressed: _previousQuestion,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: _muted),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: AnimatedOpacity(
                opacity: seleccion == null ? 0.55 : 1,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: ultima ? const [_exam, Color(0xFF7C3AED)] : const [_primary, _exam],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: seleccion == null
                        ? null
                        : [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: ElevatedButton(
                    onPressed: seleccion == null ? null : _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, altura),
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ultima ? 'Finalizar examen' : 'Siguiente',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Icon(ultima ? Icons.flag_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_preguntas.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: SafeArea(
          child: _estadoCentral(
            icono: Icons.quiz_outlined,
            titulo: 'Examen sin preguntas',
            mensaje: 'Este examen no contiene preguntas disponibles.',
            accion: OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Regresar'),
            ),
          ),
        ),
      );
    }

    final preguntaActual = _preguntas[_currentQuestionIndex] as Map<String, dynamic>;
    final String enunciado = (preguntaActual['pregunta'] ?? preguntaActual['enunciado'] ?? '').toString();
    final List<dynamic> opciones = (preguntaActual['opciones'] as List?) ?? [];
    final int? selectedOptionIndex = _respuestasUsuario[_currentQuestionIndex];
    final horizontal = context.esHorizontal;

    return PopScope(
      canPop: _respuestasUsuario.isEmpty && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSubmitting) _salir();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: _isSubmitting
            ? SafeArea(
                child: _estadoCentral(
                  icono: Icons.fact_check_rounded,
                  titulo: 'Calificando tus respuestas…',
                  mensaje: 'En un momento verás tu resultado.',
                  accion: const SizedBox(
                    width: 140,
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: _primary,
                      backgroundColor: Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ),
                ),
              )
            : SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _barraSuperior(horizontal),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd: (detalles) {
                          final v = detalles.primaryVelocity ?? 0;
                          final ultima = _currentQuestionIndex == _preguntas.length - 1;
                          if (v < -350 && selectedOptionIndex != null && !ultima) _nextQuestion();
                          if (v > 350 && _currentQuestionIndex > 0) _previousQuestion();
                        },
                        child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AnchoMaximo(
                          maximo: 800,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            reverseDuration: const Duration(milliseconds: 140),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final entra = child.key == ValueKey(_currentQuestionIndex);
                              final desde = (_haciaAdelante == entra) ? 0.08 : -0.08;
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(begin: Offset(desde, 0), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            layoutBuilder: (actual, previos) => Stack(
                              alignment: Alignment.topCenter,
                              children: [...previos, if (actual != null) actual],
                            ),
                            child: Column(
                              key: ValueKey(_currentQuestionIndex),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: horizontal ? 6 : 10),
                                _tarjetaPregunta(enunciado, horizontal),
                                SizedBox(height: horizontal ? 14 : 20),
                                for (int i = 0; i < opciones.length; i++) ...[
                                  Aparecer(
                                    orden: i + 1,
                                    duracion: const Duration(milliseconds: 260),
                                    pasoMs: 30,
                                    desplazamiento: 12,
                                    child: _opcion(i, opciones[i], selectedOptionIndex == i),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ),
                    ),
                    _barraInferior(horizontal, selectedOptionIndex),
                  ],
                ),
              ),
      ),
    );
  }
}