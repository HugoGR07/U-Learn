import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'login_view.dart';
import 'terms_view.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/ruta_suave.dart';
import '../widgets/u_fondo.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _paternoController = TextEditingController();
  final TextEditingController _maternoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _aceptaTerminos = false;

  @override
  void dispose() {
    _nameController.dispose();
    _paternoController.dispose();
    _maternoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final nombre = _nameController.text.trim();
    final apellidoPaterno = _paternoController.text.trim();
    final apellidoMaterno = _maternoController.text.trim();
    final correo = _emailController.text.trim();
    final contrasena = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validaciones
    if (nombre.isEmpty ||
        apellidoPaterno.isEmpty ||
        correo.isEmpty ||
        contrasena.isEmpty ||
        confirmPassword.isEmpty) {
      _showFloatingDialog(
        title: 'Campos incompletos',
        message: 'Por favor, completa los campos obligatorios para continuar.',
        isSuccess: false,
      );
      return;
    }

    if (contrasena != confirmPassword) {
      _showFloatingDialog(
        title: 'Contraseñas incorrectas',
        message: 'Las contraseñas no coinciden, verifícalas.',
        isSuccess: false,
      );
      return;
    }

    if (contrasena.length < 6) {
      _showFloatingDialog(
        title: 'Contraseña débil',
        message: 'La contraseña debe tener al menos 6 caracteres.',
        isSuccess: false,
      );
      return;
    }

    if (!_aceptaTerminos) {
      _showFloatingDialog(
        title: 'Falta tu aceptación',
        message: 'Para crear tu cuenta debes aceptar los Términos y Condiciones y el Aviso de Privacidad.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.register(
      nombre: nombre,
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: apellidoMaterno,
      correo: correo,
      contrasena: contrasena,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showFloatingDialog(
        title: '¡Registro exitoso! 🎉',
        message: 'Usuario registrado correctamente, inicia sesión para ingresar.',
        isSuccess: true,
        onConfirm: () {
          Navigator.pushReplacement(
            context,
            RutaSuave(page: const LoginView()),
          );
        },
      );
    } else {
      String msgError = result['message']?.toString() ?? 'No se pudo crear tu cuenta. Inténtalo de nuevo.';
      if (result['conexion'] != true &&
          (msgError.toLowerCase().contains('correo') || msgError.toLowerCase().contains('registrado'))) {
        msgError = 'El correo que ingresaste ya está registrado. Intenta con otro correo para ingresar.';
      }
      _showFloatingDialog(
        title: 'Aviso',
        message: msgError,
        isSuccess: false,
      );
    }
  }

  // NUEVA VENTANA FLOTANTE VISIBLE Y BONITA
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

    // Barra superior con botón Atrás
    final barraSuperior = Stack(
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
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ),
        const Text(
          'Crear cuenta',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D61E7),
          ),
        ),
      ],
    );

    // Logo
    final logo = Container(
      width: 70,
      height: 70,
      padding: const EdgeInsets.all(10),
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
              size: 36,
              color: Color(0xFF1D61E7),
            );
          },
        ),
      ),
    );

    const subtitulo = Text(
      'Únete a U-Learn',
      style: TextStyle(
        fontSize: 14,
        color: Color(0xFF64748B),
      ),
    );

    final campos = <Widget>[
      // Campo Nombre
      _buildInputField(
        controller: _nameController,
        hintText: 'Nombre(s)',
        icon: Icons.person_outline_rounded,
      ),

      // Campo Apellido Paterno
      _buildInputField(
        controller: _paternoController,
        hintText: 'Apellido paterno',
        icon: Icons.badge_outlined,
      ),

      // Campo Apellido Materno
      _buildInputField(
        controller: _maternoController,
        hintText: 'Apellido materno (opcional)',
        icon: Icons.badge_outlined,
      ),

      // Campo Correo
      _buildInputField(
        controller: _emailController,
        hintText: 'Correo electrónico',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
      ),

      // Campo Contraseña
      _buildInputField(
        controller: _passwordController,
        hintText: 'Contraseña',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
      ),

      // Campo Confirmar Contraseña
      _buildInputField(
        controller: _confirmPasswordController,
        hintText: 'Confirmar contraseña',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
      ),
    ];

    Widget cuadricula() => LayoutBuilder(
          builder: (context, limites) {
            final dosColumnas = limites.maxWidth >= 520;
            final ancho = dosColumnas ? (limites.maxWidth - 14) / 2 : limites.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final campo in campos) SizedBox(width: ancho, child: campo)],
            );
          },
        );

    final pie = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),

        _casillaTerminos(),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: const Color.fromARGB(255, 11, 13, 15),
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
                  'Crear cuenta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),

        const SizedBox(height: 20),

        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              '¿Ya tienes cuenta? ',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  RutaSuave(page: const LoginView()),
                );
              },
              child: const Text(
                'Iniciar sesión',
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
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            bottom: -tamanoU * 0.12,
            child: RepaintBoundary(child: UFondo(tamano: tamanoU)),
          ),
          SafeArea(
            child: horizontal
                ? Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: LayoutBuilder(
                          builder: (context, limites) => SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 12, 12, 24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: (limites.maxHeight - 36).clamp(0.0, double.infinity)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  barraSuperior,
                                  const SizedBox(height: 20),
                                  logo,
                                  const SizedBox(height: 10),
                                  subtitulo,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: EspacioTeclado(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 20, 28, 0),
                            child: AnchoMaximo(
                              maximo: 640,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [cuadricula(), pie],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : EspacioTeclado(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: AnchoMaximo(
                        maximo: 480,
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            barraSuperior,
                            const SizedBox(height: 16),
                            logo,
                            const SizedBox(height: 10),
                            subtitulo,
                            const SizedBox(height: 24),
                            cuadricula(),
                            pie,
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirTerminos(int pestana) async {
    final acepto = await Navigator.push<bool>(
      context,
      RutaSuave(
        page: TermsView(
          pestanaInicial: pestana,
          modoAceptar: true,
          yaAceptado: _aceptaTerminos,
        ),
      ),
    );
    if (acepto != null && mounted) setState(() => _aceptaTerminos = acepto);
  }

  Widget _casillaTerminos() {
    const link = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: Color(0xFF1D61E7),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFF1D61E7),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: _aceptaTerminos,
            activeColor: const Color(0xFF1D61E7),
            side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _aceptaTerminos = !_aceptaTerminos),
                  child: const Text('He leído y acepto los ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
                ),
                GestureDetector(
                  onTap: () => _abrirTerminos(0),
                  child: const Text('Términos y Condiciones',
                      style: link),
                ),
                const Text(' y el ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
                GestureDetector(
                  onTap: () => _abrirTerminos(1),
                  child: const Text('Aviso de Privacidad',
                      style: link),
                ),
                const Text('.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF94A3B8),
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
    );
  }
}