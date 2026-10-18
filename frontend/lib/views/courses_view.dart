import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'topics_view.dart';
import 'profile_view.dart'; 
import 'study_view.dart';
import '../widgets/foto_perfil.dart';
import '../widgets/encabezado_azul.dart';

class CoursesView extends StatefulWidget {
  const CoursesView({super.key});

  @override
  State<CoursesView> createState() => _CoursesViewState();
}

class _CoursesViewState extends State<CoursesView> {
  List<dynamic> _courses = [];
  bool _isLoading = true;
  bool _hasWelcomed = false;

  // Obtiene el nombre real devuelto por la BD al hacer login
  String get _userName {
    final user = ApiService.currentUser;
    if (user != null && user['nombre'] != null) {
      return user['nombre'].toString();
    }
    return 'Usuario';
  }

  @override
  void initState() {
    super.initState();
    NotificationService.loadInbox();
    _loadUserAndCourses();
  }

  String get _welcomeKey {
    final id = ApiService.currentUser?['id_usuario'] ?? ApiService.currentUser?['correo'] ?? 'anonimo';
    return 'ul_bienvenida_vista_$id';
  }

  Future<void> _mostrarBannerBienvenida() async {
    if (_hasWelcomed || !mounted) return;
    _hasWelcomed = true;

    bool primeraVez = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      primeraVez = prefs.getBool(_welcomeKey) != true;
      if (primeraVez) await prefs.setBool(_welcomeKey, true);
    } catch (_) {}

    if (!mounted) return;
    if (primeraVez) {
      _mostrarDialogoBienvenida();
      return;
    }

    // Muestra ÚNICAMENTE el banner flotante inferior de bienvenida por 3 segundos
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('👋', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Todo listo para empezar, $_userName!',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarDialogoBienvenida() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF2FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_rounded,
                      size: 36,
                      color: Color(0xFF1D61E7),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '¡Bienvenido a U-Learn, $_userName!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aprende sobre temas financieros a tu ritmo con guías creadas por inteligencia artificial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _welcomeFeature(
                          Icons.auto_awesome_rounded,
                          'Crea tu guía',
                        ),
                        const SizedBox(height: 14),
                        _welcomeFeature(
                          Icons.menu_book_rounded,
                          'Estudia',
                        ),
                        const SizedBox(height: 14),
                        _welcomeFeature(
                          Icons.quiz_rounded,
                          'Pon a prueba lo aprendido',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D61E7),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Comenzar',
                      style: TextStyle(
                        fontSize: 15,
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
      },
    );
  }

  Widget _welcomeFeature(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF2FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF1D61E7)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadUserAndCourses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Al volver de otra pantalla puede haber notificaciones nuevas
    NotificationService.loadInbox();

    try {
      final coursesData = await ApiService.getUserGuides();

      if (mounted) {
        setState(() {
          _courses = coursesData;
          _isLoading = false;
        });
        _mostrarBannerBienvenida();
      }
    } catch (e) {
      print('Error capturado en CoursesView: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarBannerBienvenida();
        if (_courses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudieron obtener los cursos ($e)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Modal con la bandeja de notificaciones locales.
  /// Al cerrarlo, todas quedan marcadas como leídas.
  void _showNotificationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ValueListenableBuilder<List<AppNotification>>(
              valueListenable: NotificationService.inbox,
              builder: (context, items, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Text(
                              'Notificaciones',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (items.isNotEmpty)
                              TextButton(
                                onPressed: NotificationService.clearInbox,
                                child: const Text(
                                  'Borrar todo',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text(
                                'No tienes notificaciones',
                                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final n = items[i];
                            return _buildNotificationTile(
                              icon: _iconFor(n.title),
                              title: n.title,
                              body: n.body,
                              time: _timeAgo(n.date),
                              unread: !n.read,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(NotificationService.markAllAsRead);
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String body,
    String? time,
    required bool unread,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                if (time != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('bienvenido')) return Icons.auto_awesome;
    if (t.contains('examen')) return Icons.quiz_rounded;
    if (t.contains('sección') || t.contains('seccion')) return Icons.check_circle_rounded;
    if (t.contains('pendiente') || t.contains('esperan')) return Icons.alarm_rounded;
    return Icons.notifications_rounded;
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 2. Cuerpo con la lista de cursos
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUserAndCourses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 1. Cabecera Azul Superior (se desplaza junto con la lista)
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Mis cursos',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (_courses.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEBF2FE),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_courses.length}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1D61E7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                                onPressed: _loadUserAndCourses,
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Estado de Carga / Vacío / Lista de Cursos
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                              ),
                            )
                          else if (_courses.isEmpty)
                            _buildEmptyState()
                          else
                            ..._courses.map((course) {
                              final int total = int.tryParse(course['total_secciones']?.toString() ?? '0') ?? 0;
                              final int completadas = int.tryParse(course['secciones_completadas']?.toString() ?? '0') ?? 0;

                              final double progress = total > 0 ? (completadas / total) : 0.0;
                              final String progressPercentage = '${(progress * 100).toInt()}%';
                              final bool isCompleted = progress >= 1.0 && total > 0;
                              final String nombreTema =
                                  (course['nombre_tema'] ?? course['titulo'] ?? 'Guía de estudio').toString();
                              final style = _getTopicStyle(nombreTema);

                              return _CourseCard(
                                title: nombreTema,
                                topicIcon: style['icon'] as IconData,
                                topicColor: style['color'] as Color,
                                progress: progress,
                                progressText: progressPercentage,
                                timeRemaining: total > 0 
                                    ? '$completadas de $total secciones completadas'
                                    : 'Sin secciones registradas',
                                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                isCompleted: isCompleted,
                                onTap: () async {
                                  final rawId = course['id_guia'] ?? course['id'];
                                  final int? idGuia = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

                                  if (idGuia == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No se pudo obtener el ID de la guía')),
                                    );
                                    return;
                                  }

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudyView(idGuia: idGuia),
                                    ),
                                  );

                                  _loadUserAndCourses();
                                },
                              );
                            }),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Botón "Agregar nuevo curso" fijo en la parte inferior
          _buildAddCourseBar(),
        ],
      ),
    );
  }

  // Barra inferior fija con el botón para agregar un curso (-> TopicsView)
  Widget _buildAddCourseBar() {
    return Container(
      // Mismo color que el fondo, sin sombra: no se nota división
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: OutlinedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TopicsView(),
                ),
              );
              _loadUserAndCourses();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_rounded, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 8),
                Text(
                  'Agregar nuevo curso',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: const [
          Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'Aún no tienes cursos creados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 4),
          Text(
            'Selecciona un tema para generar tu primera guía de estudio con IA.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /// Cabecera interactiva con nombre dinámico, modal de notificaciones y navegación a perfil
  Widget _buildHeader() {
    return EncabezadoAzul(
      grande: true,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'U',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hola, $_userName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Sigue aprendiendo y alcanza tus metas',
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Botón de Campana -> Despliega la ventana modal de notificaciones
          ValueListenableBuilder<List<AppNotification>>(
            valueListenable: NotificationService.inbox,
            builder: (context, items, _) {
              final unread = items.where((n) => !n.read).length;
              return GestureDetector(
                onTap: () => _showNotificationsModal(context),
                child: Container(
                  width: EncabezadoAzul.tamBotonGrande,
                  height: EncabezadoAzul.tamBotonGrande,
                  decoration: EncabezadoAzul.decoracionVidrio,
                  child: Center(
                    child: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 9 ? '9+' : '$unread'),
                      backgroundColor: const Color(0xFFEF4444),
                      textColor: Colors.white,
                      child: const Icon(Icons.notifications_rounded, color: Colors.amber, size: 25),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Foto de perfil -> Navega a la vista de perfil
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileView(),
                ),
              );
              if (mounted) setState(() {});
            },
            child: FotoPerfil(
              numero: FotoPerfil.desdeUsuario(ApiService.currentUser),
              size: EncabezadoAzul.tamBotonGrande,
            ),
          ),
        ],
      ),
    );
  }

  // Mismos íconos y colores que se usan al crear la guía (TopicsView)
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

}

class _CourseCard extends StatefulWidget {
  final String title;
  final IconData topicIcon;
  final Color topicColor;
  final double progress;
  final String progressText;
  final String timeRemaining;
  final Color color;
  final bool isCompleted;
  final VoidCallback? onTap;

  const _CourseCard({
    required this.title,
    required this.topicIcon,
    required this.topicColor,
    required this.progress,
    required this.progressText,
    required this.timeRemaining,
    required this.color,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final double target = widget.progress < 0 ? 0.0 : (widget.progress > 1 ? 1.0 : widget.progress);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed ? widget.topicColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.topicColor.withValues(alpha: _pressed ? 0.14 : 0.08),
                blurRadius: _pressed ? 8 : 16,
                offset: Offset(0, _pressed ? 2 : 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.topicColor.withValues(alpha: 0.22),
                      widget.topicColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.topicIcon,
                  color: widget.topicColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (widget.isCompleted)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                        else
                          AnimatedSlide(
                            offset: Offset(_pressed ? 0.25 : 0, 0),
                            duration: const Duration(milliseconds: 140),
                            child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progreso',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: target),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text(
                            '${(value * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: target),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          widget.timeRemaining,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}