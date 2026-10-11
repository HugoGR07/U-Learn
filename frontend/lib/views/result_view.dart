import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ResultView extends StatefulWidget {
  final int totalPreguntas;
  final int correctas;
  final int incorrectas;
  final int porcentaje;
  final List<Map<String, dynamic>> erroresDelExamen;
  final List<Map<String, dynamic>> examenCompleto;

  const ResultView({
    super.key,
    required this.totalPreguntas,
    required this.correctas,
    required this.incorrectas,
    required this.porcentaje,
    this.erroresDelExamen = const [],
    this.examenCompleto = const [],
  });

  /// Constructor factory para instanciar ResultView directamente desde el mapa de la API
  factory ResultView.fromMap(Map<String, dynamic> rawData) {
    final Map<String, dynamic> data =
        (rawData['resultado'] is Map<String, dynamic>)
            ? rawData['resultado']
            : rawData;

    final int total =
        int.tryParse(data['total_preguntas']?.toString() ?? '') ??
        int.tryParse(data['total']?.toString() ?? '') ??
        0;

    final int aciertos =
        int.tryParse(data['aciertos']?.toString() ?? '') ??
        int.tryParse(data['respuestas_correctas']?.toString() ?? '') ??
        0;

    final int desaciertos =
        int.tryParse(data['incorrectas']?.toString() ?? '') ??
        int.tryParse(data['respuestas_incorrectas']?.toString() ?? '') ??
        (total > aciertos ? total - aciertos : 0);

    num rawCalificacion =
        data['porcentaje'] ?? data['calificacion'] ?? data['promedio'] ?? 0;

    int pct = rawCalificacion.round();
    if (rawCalificacion > 0 && rawCalificacion <= 10) {
      pct = (rawCalificacion * 10).round();
    }

    List<Map<String, dynamic>> erroresList = [];
    if (rawData['errores'] is List) {
      erroresList = List<Map<String, dynamic>>.from(rawData['errores']);
    }

    List<Map<String, dynamic>> examenList = [];
    if (rawData['examen_completo'] is List) {
      examenList = List<Map<String, dynamic>>.from(rawData['examen_completo']);
    }

    return ResultView(
      totalPreguntas: total,
      correctas: aciertos,
      incorrectas: desaciertos,
      porcentaje: pct,
      erroresDelExamen: erroresList,
      examenCompleto: examenList,
    );
  }

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  bool _isLoading = false;

  // Función para consultar a la IA con TODOS los errores de una sola vez
  void _obtenerFundamentoGlobal() async {
    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1D61E7)),
      ),
    );

    try {
      final respuestaAI = await ApiService.askAiTutor(
        prompt: 'Explícame de forma unificada los fundamentos teóricos de todos los errores cometidos en este examen.',
        examenCompleto: widget.examenCompleto,
        errores: widget.erroresDelExamen, // Mandamos la lista completa de errores
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      _mostrarModalFundamento(
        'Retroalimentación Global',
        respuestaAI.isNotEmpty ? respuestaAI : 'No se pudo generar la retroalimentación en este momento.',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader
      _mostrarModalFundamento('Aviso', 'Error de conexión al consultar el tutor de IA.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarModalFundamento(String titulo, String contenido) {
    // Limpieza profunda de asteriscos, guiones de markdown y separadores sobrantes
    String contenidoLimpiado = contenido
        .replaceAll('### ', '')
        .replaceAll('## ', '')
        .replaceAll('# ', '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('---', '')
        .replaceAll('\r\n', '\n');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        backgroundColor: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.90,
          constraints: const BoxConstraints(maxHeight: 650),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('🧠', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(thickness: 1.2, color: Color(0xFFF1F5F9)),
              ),
              // Contenido con diseño estilizado y ordenado
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    contenidoLimpiado.trim(),
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.7,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Botón inferior
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '✨ Entendido y Repasado',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Resultados y Fundamentos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Destellos superiores
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 8),
                  Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 8),
                  Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Icono de Trofeo / Medalla
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Center(
                  child: Icon(
                    widget.porcentaje >= 60 ? Icons.emoji_events_rounded : Icons.stars_rounded,
                    size: 80,
                    color: widget.porcentaje >= 60 ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Título y Subtítulo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.porcentaje >= 60 ? '¡Felicidades!' : '¡Buen intento!',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.porcentaje >= 60 ? '🎉' : '💪', style: const TextStyle(fontSize: 26)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Has completado la evaluación de la sección',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),

              // 4. Calificación Promedio
              const Text(
                'Tu calificación',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.porcentaje}%',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Color(0xFF1D61E7), height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.correctas} de ${widget.totalPreguntas} correctas',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 28),

              // 5. Tarjetas de Estadísticas
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${widget.correctas}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Correctas',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${widget.incorrectas}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Incorrectas',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 6. Sección de Errores detectados y Botón Global de IA
              if (widget.erroresDelExamen.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '🔍 Resumen de Preguntas Incorrectas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Lista limpia informativa (sin botones individuales)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.erroresDelExamen.length,
                  itemBuilder: (context, index) {
                    final error = widget.erroresDelExamen[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pregunta: ${error['pregunta'] ?? error['texto_pregunta'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          Text('• Tu respuesta: ${error['respuesta_usuario'] ?? ''}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                          Text('• Respuesta correcta: ${error['respuesta_correcta'] ?? ''}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // UN SOLO BOTÓN GLOBAL PARA CONSULTAR A LA IA
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _obtenerFundamentoGlobal,
                  icon: const Icon(Icons.psychology_rounded, size: 20),
                  label: const Text('Ver Fundamento Teórico Global de Errores'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF1D61E7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                const Text(
                  '¡Excelente trabajo! No tuviste errores en este examen.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 24),
              ],

              // 7. Botones de Navegación principales
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFF1D61E7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Ver plan de estudio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Color(0xFF1D61E7), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Volver a mis cursos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D61E7)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}