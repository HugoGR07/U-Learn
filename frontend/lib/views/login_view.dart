import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'register_view.dart';
import 'forgotpss_view.dart';
import 'courses_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showFloatingDialog(
        title: 'Campos incompletos',
        message: 'Por favor, ingresa tu correo y contraseña para continuar.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        correo: email,
        contrasena: password,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (result['success']) {
        // Redirigir directamente a la pantalla de Cursos
        // (El mensaje de bienvenida ya se muestra automáticamente allá durante 3 segundos)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CoursesView()),
          (route) => false,
        );
      } else {
        _showFloatingDialog(
          title: 'Acceso denegado',
          message: result['message'] ?? 'Credenciales inválidas, verifica tus datos.',
          isSuccess: false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showFloatingDialog(
        title: 'Error de conexión',
        message: 'No se pudo conectar con el servidor. Inténtalo más tarde.',
        isSuccess: false,
      );
    }
  }

  // Ignora toques mientras la pantalla todavía está entrando (animación).
  // Evita que un toque "fantasma" (p. ej. el doble toque en "Cerrar sesión")
  // caiga sobre "¿Olvidaste tu contraseña?" y abra esa pantalla sin querer.
  bool get _pantallaLista {
    final route = ModalRoute.of(context);
    if (route == null) return true;
    final animacionTerminada = route.animation?.status == AnimationStatus.completed;
    return route.isCurrent && animacionTerminada;
  }

  // VENTANA FLOTANTE VISIBLE Y BONITA PARA MENSAJES DE LOGIN
  void _showFloatingDialog({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1E293B),
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Logo U-Learn
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(12),
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
                        size: 40,
                        color: Color(0xFF1D61E7),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'U-Learn',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D61E7),
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Bienvenido de nuevo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Inicia sesión para continuar',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 32),

              // Campo Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Correo electrónico',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1D61E7), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Campo Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.remove_red_eye_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1D61E7), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (!_pantallaLista) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotpssView()),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D61E7),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Botón Iniciar Sesión
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFF1D61E7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿No tienes cuenta? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (!_pantallaLista) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterView()),
                      );
                    },
                    child: const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D61E7),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}