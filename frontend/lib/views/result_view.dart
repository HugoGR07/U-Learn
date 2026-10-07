// lib/views/result_view.dart
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
    required this.erroresDelExamen,
    required this.examenCompleto,
  });

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  bool _isLoading = false;

  void _obtenerFundamentoDirecto(Map<String, dynamic> errorItem, int indexPregunta) async {
    setState(() => _isLoading = true);

    // Mostramos un indicador de carga rápido mientras Gemini procesa todo el curso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1D61E7)),
      ),
    );

    try {
      final respuestaAI = await ApiService.askAiTutor(
        prompt: 'Fundamento directo',
        examenCompleto: widget.examenCompleto,
        errores: [errorItem],
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      // Mostrar el fundamento directo en una ventana emergente limpia
      _mostrarModalFundamento(
        'Fundamento - Pregunta ${indexPregunta + 1}',
        respuestaAI.isNotEmpty ? respuestaAI : 'No se pudo generar el fundamento en este momento.',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader
      _mostrarModalFundamento('Aviso', 'Error de conexión al consultar el fundamento del curso.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarModalFundamento(String titulo, String contenido) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con Icono y Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF1D61E7), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
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
              const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

              // Contenido con scroll y diseño limpio
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    // Limpiamos un poco los símbolos excesivos de markdown si no usas el paquete externo
                    contenido
                        .replaceAll('### ', '')
                        .replaceAll('## ', '')
                        .replaceAll('**', ''),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Botón de acción inferior estético
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D61E7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Entendido y Repasado',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
          'Resultados y Fundamentos del Curso',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tarjeta de resumen de calificaciones
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreItem('Calificación', '${widget.porcentaje}%', const Color(0xFF1D61E7)),
                _buildScoreItem('Aciertos', '${widget.correctas}/${widget.totalPreguntas}', const Color(0xFF10B981)),
                _buildScoreItem('Errores', '${widget.incorrectas}', const Color(0xFFEF4444)),
              ],
            ),
          ),

          // Lista estática con los errores detectados y su resumen inicial
          Expanded(
            child: widget.erroresDelExamen.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.erroresDelExamen.length,
                    itemBuilder: (context, index) {
                      final error = widget.erroresDelExamen[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pregunta ${index + 1}: ${error['pregunta']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            Text('• Tu respuesta: ${error['respuesta_usuario']}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                            Text('• Respuesta correcta: ${error['respuesta_correcta']}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : () => _obtenerFundamentoDirecto(error, index),
                                icon: const Icon(Icons.psychology_outlined, size: 16),
                                label: const Text('Ver Fundamento Teórico'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D61E7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      '¡Excelente trabajo! No tuviste errores en este examen.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
          ),

          // Barra inferior fija con el aviso legal obligatorio
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aviso importante: Esta herramienta es estrictamente informativa y educativa. No constituye asesoría personalizada, legal o médica.',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }
}