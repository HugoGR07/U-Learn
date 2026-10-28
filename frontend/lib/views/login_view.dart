import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'register_view.dart';
import 'forgotpss_view.dart';
import 'courses_view.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/ruta_suave.dart';
import '../widgets/u_fondo.dart';
import '../widgets/validaciones.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      final faltan = email.isEmpty || password.isEmpty;
      _showFloatingDialog(
        title: faltan ? 'Campos incompletos' : 'Correo inválido',
        message: faltan
            ? 'Por favor, ingresa tu correo y contraseña para continuar.'
            : 'Ingresa un correo electrónico válido para continuar.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      correo: email,
      contrasena: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Redirigir directamente a la pantalla de Cursos
      // (El mensaje de bienvenida ya se muestra automáticamente allá durante 3 segundos)
      Navigator.pushAndRemoveUntil(
        context,
        RutaSuave(page: const CoursesView()),
        (route) => false,
      );
    } else {
      _showFloatingDialog(
        title: 'Acceso denegado',
        message: result['message']?.toString() ?? 'Credenciales inválidas, verifica tus datos.',
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
    AlertaFlotante.mostrar(
      context,
      titulo: title,
      mensaje: message,
      tipo: isSuccess ? TipoAlerta.exito : TipoAlerta.error,
      alConfirmar: onConfirm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final horizontal = context.esHorizontal || pantalla.width >= 900;
    final double tamanoU = (pantalla.shortestSide * 0.85).clamp(240.0, 460.0);

    final botonAtras = IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Color(0xFF1E293B),
        size: 20,
      ),
      onPressed: () {
        Navigator.popUntil(context, (route) => route.isFirst);
      },
    );

    // Logo U-Learn
    final logo = Container(
      width: horizontal ? 72 : 80,
      height: horizontal ? 72 : 80,
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
    );

    final encabezado = [
      logo,
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
      SizedBox(height: horizontal ? 16 : 24),
      const Text(
        'Bienvenido de nuevo',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Inicia sesión para continuar',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF64748B),
        ),
      ),
    ];

    final formulario = Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          inputFormatters: Validar.formatoCorreo,
          validator: Validar.correo,
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
            errorBorder: Validar.bordeError(16),
            focusedErrorBorder: Validar.bordeErrorFoco(16),
            errorStyle: Validar.estiloError,
            errorMaxLines: 2,
          ),
        ),

        const SizedBox(height: 16),

        // Campo Password
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          enableSuggestions: false,
          autocorrect: false,
          validator: Validar.contrasenaLogin,
          onFieldSubmitted: (_) {
            if (!_isLoading) _handleLogin();
          },
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
            errorBorder: Validar.bordeError(16),
            focusedErrorBorder: Validar.bordeErrorFoco(16),
            errorStyle: Validar.estiloError,
            errorMaxLines: 2,
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
                RutaSuave(page: const ForgotpssView()),
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

        SizedBox(height: horizontal ? 20 : 28),

        // Botón Iniciar Sesión
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: const Color(0xFF1D61E7),
            disabledBackgroundColor: const Color(0xFF1D61E7).withOpacity(0.6),
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

        SizedBox(height: horizontal ? 18 : 24),

        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
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
                  RutaSuave(page: const RegisterView()),
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
      ],
    ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: UFondo(tamano: tamanoU),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, limites) {
                final contenido = horizontal
                    ? Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(32, 56, 16, 24),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: (limites.maxHeight - 80).clamp(0.0, double.infinity)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: encabezado,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 24, 32, 24),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: (limites.maxHeight - 48).clamp(0.0, double.infinity)),
                                child: Center(
                                  child: AnchoMaximo(maximo: 440, child: formulario),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 56, 28, 20),
                        child: AnchoMaximo(
                          maximo: 480,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: (limites.maxHeight - 76).clamp(0.0, double.infinity)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ...encabezado,
                                const SizedBox(height: 32),
                                formulario,
                              ],
                            ),
                          ),
                        ),
                      );

                return Stack(
                  children: [
                    Positioned.fill(child: EspacioTeclado(child: contenido)),
                    Positioned(top: 8, left: 8, child: botonAtras),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}