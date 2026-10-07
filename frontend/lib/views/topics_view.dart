import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import './generation_view.dart';

class TopicsView extends StatefulWidget {
  const TopicsView({super.key});

  @override
  State<TopicsView> createState() => _TopicsViewState();
}

class _TopicsViewState extends State<TopicsView> {
  int? selectedTopicId;
  String selectedTopicName = '';
  String selectedDuration = '2 semanas';
  bool isFetchingTopics = true;
  bool isLoading = false;

  List<dynamic> topicsFromDb = [];

  final List<String> durations = ['1 semana', '2 semanas', '3 semanas', '1 mes'];

  @override
  void initState() {
    super.initState();
    _loadTopicsFromBackend();
  }

  // 1. Cargar temas desde PostgreSQL
  Future<void> _loadTopicsFromBackend() async {
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener los temas: $e'),
          backgroundColor: Colors.red,
        ),
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

  // 2. Generar el curso enviando la petición al Backend
  Future<void> _generateCourse() async {
    if (selectedTopicName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un tema primero')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/guides/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.token}',
        },
        body: jsonEncode({
          'tema': selectedTopicName,
          'nivel': 'Intermedio',
          'duracion': selectedDuration,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Curso de "$selectedTopicName" generado con éxito!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );

          // Regresar a la vista de cursos indicando éxito
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(data['message'] ?? 'Error al generar el curso');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: isFetchingTopics
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D61E7)))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 1. Barra Superior
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
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ),
                        const Text(
                          'Nuevo curso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 2. Sección: ¿Qué deseas aprender?
                    const Text(
                      '¿Qué deseas aprender?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Selecciona el tema que más te interese',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Grid de temas dinámico
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: topicsFromDb.length,
                      itemBuilder: (context, index) {
                        final topic = topicsFromDb[index];
                        final isSelected = selectedTopicId == topic['id_tema'];
                        final style = _getTopicStyle(topic['nombre_tema'] ?? '');

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedTopicId = topic['id_tema'];
                              selectedTopicName = topic['nombre_tema'] ?? '';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF1D61E7) : const Color(0xFFE2E8F0),
                                width: isSelected ? 2.0 : 1.2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (isSelected)
                                  const Positioned(
                                    top: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Color(0xFF1D61E7),
                                      child: Icon(Icons.check, size: 12, color: Colors.white),
                                    ),
                                  ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        style['icon'],
                                        color: style['color'],
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        topic['nombre_tema'] ?? '',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // 3. Sección: Duración
                    const Text(
                      '¿En cuánto tiempo deseas terminarlo?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: durations.map((duration) {
                          final isSelected = selectedDuration == duration;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: ChoiceChip(
                              label: Text(duration),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    selectedDuration = duration;
                                  });
                                }
                              },
                              selectedColor: const Color(0xFF1D61E7),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF1D61E7) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // 4. Botón Generar Mi Guía
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedTopicName.isNotEmpty) {
                          // Abre la pantalla de carga e inicia la generación
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GenerationView(
                                selectedTopic: selectedTopicName,
                              ),
                            ),
                          );

                          // Si terminó de generar con éxito (result == true), regresa a Cursos
                          if (result == true && mounted) {
                            Navigator.pop(context, true); 
                          }
                        }
                      },
                      child: const Text('Generar mi guía'),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}