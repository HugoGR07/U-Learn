import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_view.dart';
import 'home_view.dart';
import '../services/notification_service.dart';
import '../widgets/foto_perfil.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _reminderNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final local = await NotificationService.loadPrefs();
    final email = await ApiService.getNotificationSettings();
    if (!mounted) return;
    setState(() {
      _pushNotifications = local.push;
      _reminderNotifications = local.reminder;
      _emailNotifications = email ?? _emailNotifications;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // VENTANA FLOTANTE (mismo estilo que login, registro y recuperar contraseña)
  void _showFloatingDialog({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (onConfirm != null) onConfirm();
                  },
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
                    'Aceptar',
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

  String get _fullName {
    final user = ApiService.currentUser;
    if (user != null) {
      final nombre = user['nombre'] ?? '';
      final appPaterno = user['apellido_paterno'] ?? '';
      final appMaterno = user['apellido_materno'] ?? '';
      final completo = '$nombre $appPaterno $appMaterno'.trim();
      return completo.isNotEmpty ? completo : 'Usuario U-Learn';
    }
    return 'Usuario U-Learn';
  }

  String get _email {
    final user = ApiService.currentUser;
    return user?['correo'] ?? 'correo@ejemplo.com';
  }

  void _showModal({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: const Color(0xFF1D61E7), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              ...children,
            ],
          ),
        );
      },
    );
  }

  // 1. Modal: Información Personal Editable (Con Nombre, Apellidos y Correo)
  void _showPersonalInfoModal() {
    final user = ApiService.currentUser ?? {};
    final nombreCtrl = TextEditingController(text: user['nombre'] ?? '');
    final paternoCtrl = TextEditingController(text: user['apellido_paterno'] ?? '');
    final maternoCtrl = TextEditingController(text: user['apellido_materno'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.person_outline_rounded, color: Color(0xFF1D61E7)),
                          SizedBox(width: 8),
                          Text(
                            'Información personal',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  
                  // Campo Nombre(s)
                  _buildInputField('Nombre(s)', nombreCtrl),
                  const SizedBox(height: 12),
                  
                  // Campo Apellido Paterno
                  _buildInputField('Apellido Paterno', paternoCtrl),
                  const SizedBox(height: 12),

                  // Campo Apellido Materno
                  _buildInputField('Apellido Materno', maternoCtrl),
                  const SizedBox(height: 12),

                  // Campo de Correo Electrónico (Solo Lectura)
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: _email),
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico (no editable)',
                      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botón para actualizar datos en PostgreSQL
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nombreCtrl.text.trim().isEmpty || paternoCtrl.text.trim().isEmpty) {
                              _showFloatingDialog(
                                title: 'Campos incompletos',
                                message: 'El nombre y el apellido paterno son obligatorios.',
                                isSuccess: false,
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);

                            Map<String, dynamic> res;
                            try {
                              res = await ApiService.updateProfile(
                                nombre: nombreCtrl.text.trim(),
                                apellidoPaterno: paternoCtrl.text.trim(),
                                apellidoMaterno: maternoCtrl.text.trim(),
                              );
                            } catch (_) {
                              if (!mounted) return;
                              setModalState(() => isSaving = false);
                              _showFloatingDialog(
                                title: 'Error de conexión',
                                message: 'No se pudo conectar con el servidor. Inténtalo más tarde.',
                                isSuccess: false,
                              );
                              return;
                            }

                            if (!mounted) return;
                            setModalState(() => isSaving = false);

                            if (res['success'] == true) {
                              Navigator.pop(context); // Cierra el formulario solo si se guardó
                              setState(() {}); // Actualiza la pantalla principal con el nuevo nombre
                              _showFloatingDialog(
                                title: '¡Datos actualizados! 🎉',
                                message: 'Tu información personal se guardó correctamente.',
                                isSuccess: true,
                              );
                            } else {
                              _showFloatingDialog(
                                title: 'Aviso',
                                message: res['message']?.toString() ??
                                    'No se pudieron actualizar tus datos, inténtalo de nuevo.',
                                isSuccess: false,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFF1D61E7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Actualizar datos',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFotoPerfilModal() {
    int? seleccion = FotoPerfil.desdeUsuario(ApiService.currentUser);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.photo_camera_outlined, color: Color(0xFF1D61E7)),
                          SizedBox(width: 8),
                          Text(
                            'Foto de perfil',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text(
                    'Elige una de las imágenes disponibles:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: FotoPerfil.total,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final numero = index + 1;
                      final isSelected = seleccion == numero;
                      return GestureDetector(
                        onTap: isSaving ? null : () => setModalState(() => seleccion = numero),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              FotoPerfil(numero: numero, size: constraints.maxWidth),
                              if (isSelected)
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Color(0xFF1D61E7),
                                      child: Icon(Icons.check, size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving || seleccion == null
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            final res = await ApiService.updateProfilePhoto(seleccion!);
                            if (!mounted) return;
                            setModalState(() => isSaving = false);

                            if (res['success'] == true) {
                              Navigator.pop(context);
                              setState(() {});
                              _showFloatingDialog(
                                title: '¡Foto actualizada! 🎉',
                                message: 'Tu nueva foto de perfil se guardó correctamente.',
                                isSuccess: true,
                              );
                            } else {
                              _showFloatingDialog(
                                title: 'Aviso',
                                message: res['message']?.toString() ??
                                    'No se pudo guardar tu foto, inténtalo de nuevo.',
                                isSuccess: false,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFF1D61E7),
                      disabledBackgroundColor: const Color(0xFF93B4F5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Guardar foto',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. Modal: Cambiar Contraseña Funcional
  void _showChangePasswordModal() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isChanging = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.lock_outline_rounded, color: Color(0xFF1D61E7)),
                          SizedBox(width: 8),
                          Text(
                            'Cambiar contraseña',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildPasswordField('Contraseña actual', currentPassController),
                  const SizedBox(height: 12),
                  _buildPasswordField('Nueva contraseña', newPassController),
                  const SizedBox(height: 12),
                  _buildPasswordField('Confirmar nueva contraseña', confirmPassController),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isChanging
                        ? null
                        : () async {
                            final currentPass = currentPassController.text.trim();
                            final newPass = newPassController.text.trim();
                            final confirmPass = confirmPassController.text.trim();

                            if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                              _showFloatingDialog(
                                title: 'Campos incompletos',
                                message: 'Por favor, completa todos los campos para continuar.',
                                isSuccess: false,
                              );
                              return;
                            }

                            if (newPass != confirmPass) {
                              _showFloatingDialog(
                                title: 'Contraseñas incorrectas',
                                message: 'Las nuevas contraseñas no coinciden, verifícalas.',
                                isSuccess: false,
                              );
                              return;
                            }

                            if (newPass.length < 6) {
                              _showFloatingDialog(
                                title: 'Contraseña débil',
                                message: 'La contraseña debe tener al menos 6 caracteres.',
                                isSuccess: false,
                              );
                              return;
                            }

                            setModalState(() => isChanging = true);

                            Map<String, dynamic> res;
                            try {
                              res = await ApiService.changePassword(
                                currentPassword: currentPass,
                                newPassword: newPass,
                              );
                            } catch (_) {
                              if (!mounted) return;
                              setModalState(() => isChanging = false);
                              _showFloatingDialog(
                                title: 'Error de conexión',
                                message: 'No se pudo conectar con el servidor. Inténtalo más tarde.',
                                isSuccess: false,
                              );
                              return;
                            }

                            if (!mounted) return;
                            setModalState(() => isChanging = false);

                            if (res['success'] == true) {
                              Navigator.pop(context); // Cierra el formulario solo si se guardó
                              _showFloatingDialog(
                                title: '¡Contraseña actualizada! 🎉',
                                message: 'Tu contraseña se cambió correctamente.',
                                isSuccess: true,
                              );
                            } else {
                              _showFloatingDialog(
                                title: 'Aviso',
                                message: res['message']?.toString() ??
                                    'No se pudo cambiar la contraseña, verifica tu contraseña actual.',
                                isSuccess: false,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFF1D61E7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isChanging
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Guardar contraseña', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  // 3. Modal: Configuración de Notificaciones
  void _showNotificationsSettingsModal() {
    _showModal(
      title: 'Notificaciones',
      icon: Icons.notifications_none_rounded,
      children: [
        StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              children: [
                SwitchListTile(
                  activeColor: const Color(0xFF1D61E7),
                  title: const Text('Notificaciones Push', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Recibe alertas sobre tu progreso diario', style: TextStyle(fontSize: 12)),
                  value: _pushNotifications,
                  onChanged: (val) async {
                    if (val && !await NotificationService.requestPermission()) {
                      _snack('Activa los permisos de notificaciones en Ajustes del teléfono.');
                      return;
                    }
                    await NotificationService.setPush(val);
                    setModalState(() => _pushNotifications = val);
                    setState(() => _pushNotifications = val);
                    if (val) {
                      NotificationService.showProgress(
                          'Notificaciones activadas', 'Te avisaremos de tu progreso en U-Learn.');
                    }
                  },
                ),
                const Divider(),
                SwitchListTile(
                  activeColor: const Color(0xFF1D61E7),
                  title: const Text('Alertas por Correo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Resumen semanal de tu progreso', style: TextStyle(fontSize: 12)),
                  value: _emailNotifications,
                  onChanged: (val) async {
                    final ok = await ApiService.updateNotificationSettings(emailAlerts: val);
                    if (!ok) {
                      _snack('No se pudo guardar la preferencia.');
                      return;
                    }
                    setModalState(() => _emailNotifications = val);
                    setState(() => _emailNotifications = val);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  activeColor: const Color(0xFF1D61E7),
                  title: const Text('Recordatorios de Estudio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Aviso para realizar tus exámenes pendientes', style: TextStyle(fontSize: 12)),
                  value: _reminderNotifications,
                  onChanged: (val) async {
                    if (val && !await NotificationService.requestPermission()) {
                      _snack('Activa los permisos de notificaciones en Ajustes del teléfono.');
                      return;
                    }
                    await NotificationService.setReminder(val);
                    setModalState(() => _reminderNotifications = val);
                    setState(() => _reminderNotifications = val);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // 4. Modal: Ayuda y Soporte con Solucionador de Errores Frecuentes
  void _showHelpSupportModal() {
    _showModal(
      title: 'Ayuda y soporte',
      icon: Icons.help_outline_rounded,
      children: [
        const Text(
          'Problemas frecuentes y solución de errores:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        _buildFaqTile(
          'Error "No se pudo conectar con el servidor"',
          'Asegúrate de tener conexión a Internet y que tu backend Node.js esté activo en el mismo puerto.',
        ),
        _buildFaqTile(
          'Mi guía con IA tarda en generar',
          'La generación del plan de estudio evalúa múltiples preguntas y lecciones. El proceso suele tomar de 5 a 12 segundos.',
        ),
        _buildFaqTile(
          'Error al guardar mis respuestas del examen',
          'Verifica que tu sesión no haya expirado. Si persiste, cierra e inicia sesión nuevamente.',
        ),
        const Divider(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF1D61E7)),
          title: const Text('¿Necesitas ayuda adicional?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: const Text('Escríbenos a soporte@ulearn.com', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text(answer, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
        ),
      ],
    );
  }

  // 5. Modal: Acerca de U-Learn (Inspirador y Descriptivo)
  void _showAboutModal() {
    _showModal(
      title: 'Acerca de U-Learn',
      icon: Icons.info_outline_rounded,
      children: [
        const Center(
          child: Column(
            children: [
              Text('U', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF1D61E7))),
              SizedBox(height: 2),
              Text('U-Learn App v1.0.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 12),
              Text(
                'U-Learn es tu tutor personal de educación financiera impulsado por Inteligencia Artificial.\n\n'
                'Aprende a dominar tus tarjetas de crédito, construir presupuestos reales, crear fondos de ahorro e iniciar tus primeras inversiones sin lenguaje complicado.\n\n'
                'Nuestra metodología divide temas complejos en guías de estudio interactivas con exámenes de evaluación inmediata para medir tu aprendizaje paso a paso.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 18),
              Text('Desarrollado con ❤️ por el equipo Syncore © 2026', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // Limpia la sesión y deja la pila de navegación como al abrir la app:
  // HomeView (base) -> LoginView. Así el botón "atrás" del login sigue funcionando.
  void _cerrarSesion() {
    ApiService.token = null;
    ApiService.currentUser = null;

    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeView()),
      (route) => false,
    );
    navigator.push(
      MaterialPageRoute(builder: (_) => const LoginView()),
    );
  }

  // 6. Confirmación de Cerrar Sesión
  bool _cerrandoSesion = false;

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('¿Cerrar sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Tendrás que volver a ingresar tus credenciales para acceder a tus cursos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                // Evita que un doble toque dispare el cierre de sesión dos veces
                if (_cerrandoSesion) return;
                _cerrandoSesion = true;
                Navigator.pop(dialogContext);
                _cerrarSesion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Cabecera Azul Compacta con Avatar Flotante Superior
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 55),
                  child: Container(
                    height: 150, // Altura reducida para recortar el espacio superior
                    width: double.infinity,
                    alignment: Alignment.topCenter,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D61E7),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                            const Expanded(
                              child: Text(
                                'Mi perfil',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48), // Balance con botón atrás
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Avatar Circular sobrepuesto
                Positioned(
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showFotoPerfilModal,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDBA74),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: FotoPerfil(
                            numero: FotoPerfil.desdeUsuario(ApiService.currentUser),
                            size: 103,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _showFotoPerfilModal,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D61E7),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            // 2. Información del Usuario (Dinámica)
            Text(
              _fullName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 2),

            Text(
              _email,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Menú de Opciones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildProfileOption(
                    icon: Icons.person_outline_rounded,
                    title: 'Información personal',
                    onTap: _showPersonalInfoModal,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    icon: Icons.photo_camera_outlined,
                    title: 'Foto de perfil',
                    onTap: _showFotoPerfilModal,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    icon: Icons.lock_outline_rounded,
                    title: 'Cambiar contraseña',
                    onTap: _showChangePasswordModal,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notificaciones',
                    iconColor: const Color(0xFFD97706),
                    onTap: _showNotificationsSettingsModal,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    icon: Icons.help_outline_rounded,
                    title: 'Ayuda y soporte',
                    onTap: _showHelpSupportModal,
                  ),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    icon: Icons.info_outline_rounded,
                    title: 'Acerca de U-Learn',
                    onTap: _showAboutModal,
                  ),

                  const SizedBox(height: 28),

                  // 4. Botón Cerrar Sesión
                  OutlinedButton(
                    onPressed: _showLogoutDialog,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    Color iconColor = const Color(0xFF64748B),
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}