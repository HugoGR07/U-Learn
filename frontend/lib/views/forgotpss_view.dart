import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/alerta_flotante.dart';
import '../widgets/responsivo.dart';
import '../widgets/validaciones.dart';

class ForgotpssView extends StatefulWidget {
  const ForgotpssView({super.key});

  @override
  State<ForgotpssView> createState() => _ForgotpssViewState();
}

class _ForgotpssViewState extends State<ForgotpssView> {
  static const _azul = Color(0xFF1D61E7);
  static const _oscuro = Color(0xFF1E293B);
  static const _gris = Color(0xFF64748B);

  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _passController = TextEditingController();
  final _pass2Controller = TextEditingController();

  final _correoKey = GlobalKey<FormFieldState<String>>();
  final _codigoKey = GlobalKey<FormFieldState<String>>();
  final _passKey = GlobalKey<FormFieldState<String>>();
  final _pass2Key = GlobalKey<FormFieldState<String>>();

  int _paso = 0;
  bool _cargando = false;
  bool _ocultarPass = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _passController.dispose();
    _pass2Controller.dispose();
    super.dispose();
  }

  // VENTANA FLOTANTE (mismo estilo que login y registro)
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

  Future<void> _enviarCodigo() async {
    final correo = _emailController.text.trim();
    FocusScope.of(context).unfocus();
    if (_paso == 0) _correoKey.currentState?.validate();
    if (Validar.correo(correo) != null) {
      _showFloatingDialog(
        title: 'Correo inválido',
        message: 'Ingresa un correo electrónico válido para continuar.',
        isSuccess: false,
      );
      return;
    }
    setState(() => _cargando = true);
    final res = await ApiService.forgotPassword(correo);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (res['success'] == true) {
      _codigoController.clear();
      setState(() => _paso = 1);
      _showFloatingDialog(
        title: 'Código enviado 📩',
        message: res['message']?.toString() ??
            'Te enviamos un código de 6 dígitos a tu correo.',
        isSuccess: true,
      );
    } else {
      _showFloatingDialog(
        title: 'Aviso',
        message: res['message']?.toString() ??
            'No se pudo enviar el código, inténtalo de nuevo.',
        isSuccess: false,
      );
    }
  }

  Future<void> _verificarCodigo() async {
    final codigo = _codigoController.text.trim();
    FocusScope.of(context).unfocus();
    _codigoKey.currentState?.validate();
    if (Validar.codigo(codigo) != null) {
      _showFloatingDialog(
        title: 'Código incompleto',
        message: 'Ingresa el código de 6 dígitos que te enviamos.',
        isSuccess: false,
      );
      return;
    }
    setState(() => _cargando = true);
    final res = await ApiService.verifyResetCode(_emailController.text.trim(), codigo);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (res['success'] == true) {
      setState(() => _paso = 2);
    } else {
      _showFloatingDialog(
        title: 'Código incorrecto',
        message: res['message']?.toString() ??
            'El código no es válido o ya venció, verifícalo.',
        isSuccess: false,
      );
    }
  }

  Future<void> _cambiarContrasena() async {
    final pass = _passController.text;
    FocusScope.of(context).unfocus();
    _passKey.currentState?.validate();
    _pass2Key.currentState?.validate();
    if (pass.isEmpty || _pass2Controller.text.isEmpty) {
      _showFloatingDialog(
        title: 'Campos incompletos',
        message: 'Por favor, escribe y confirma tu nueva contraseña.',
        isSuccess: false,
      );
      return;
    }
    final errorPass = Validar.contrasenaNueva(pass);
    if (errorPass != null) {
      _showFloatingDialog(
        title: 'Contraseña débil',
        message: 'La contraseña debe tener al menos ${Validar.minContrasena} caracteres e incluir letras y números, sin espacios.',
        isSuccess: false,
      );
      return;
    }
    if (pass != _pass2Controller.text) {
      _showFloatingDialog(
        title: 'Contraseñas incorrectas',
        message: 'Las contraseñas no coinciden, verifícalas.',
        isSuccess: false,
      );
      return;
    }
    setState(() => _cargando = true);
    final res = await ApiService.resetPassword(
      correo: _emailController.text.trim(),
      codigo: _codigoController.text.trim(),
      nuevaContrasena: pass,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (res['success'] == true) {
      _showFloatingDialog(
        title: '¡Contraseña actualizada! 🎉',
        message: 'Tu contraseña se cambió correctamente, inicia sesión para ingresar.',
        isSuccess: true,
        onConfirm: () {
          if (mounted) Navigator.pop(context);
        },
      );
    } else {
      _showFloatingDialog(
        title: 'Aviso',
        message: res['message']?.toString() ??
            'No se pudo cambiar la contraseña, inténtalo de nuevo.',
        isSuccess: false,
      );
    }
  }

  void _atras() {
    if (_paso == 0 || _cargando) {
      if (!_cargando) Navigator.pop(context);
      return;
    }
    setState(() => _paso = _paso == 2 ? 1 : 0);
  }

  InputDecoration _decoracion(String hint, IconData icono, {Widget? sufijo}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icono, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: sufijo,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _azul, width: 1.5),
      ),
      errorBorder: Validar.bordeError(16),
      focusedErrorBorder: Validar.bordeErrorFoco(16),
      errorStyle: Validar.estiloError,
      errorMaxLines: 2,
    );
  }

  Widget _boton(String texto, VoidCallback accion) {
    return ElevatedButton(
      onPressed: _cargando ? null : accion,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: _azul,
        disabledBackgroundColor: _azul.withOpacity(0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _cargando
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : Text(
              texto,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
    );
  }

  Widget _encabezado(IconData icono, String titulo, String descripcion) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: _azul.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icono, size: 40, color: _azul),
        ),
        const SizedBox(height: 24),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _oscuro),
        ),
        const SizedBox(height: 8),
        Text(
          descripcion,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _gris, height: 1.4),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _pasoCorreo() {
    return Column(
      children: [
        _encabezado(
          Icons.lock_reset_rounded,
          '¿Olvidaste tu contraseña?',
          'Ingresa tu correo electrónico y te enviaremos un código para restablecerla.',
        ),
        TextFormField(
          key: _correoKey,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          inputFormatters: Validar.formatoCorreo,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: Validar.correo,
          style: const TextStyle(fontSize: 14, color: _oscuro),
          decoration: _decoracion('Correo electrónico', Icons.email_outlined),
          onFieldSubmitted: (_) => _enviarCodigo(),
        ),
        const SizedBox(height: 24),
        _boton('Enviar código', _enviarCodigo),
      ],
    );
  }

  Widget _pasoCodigo() {
    return Column(
      children: [
        _encabezado(
          Icons.mark_email_read_outlined,
          'Revisa tu correo',
          'Enviamos un código de 6 dígitos a\n${_emailController.text.trim()}\nEl código vence en 15 minutos.',
        ),
        TextFormField(
          key: _codigoKey,
          controller: _codigoController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: Validar.codigo,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold, color: _oscuro),
          decoration: _decoracion('000000', Icons.pin_outlined),
          onFieldSubmitted: (_) => _verificarCodigo(),
        ),
        const SizedBox(height: 24),
        _boton('Verificar código', _verificarCodigo),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cargando ? null : _enviarCodigo,
          child: const Text(
            '¿No te llegó? Reenviar código',
            style: TextStyle(color: _azul, fontWeight: FontWeight.w600),
          ),
        ),
        const Text(
          'Revisa también tu carpeta de spam.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _pasoNuevaContrasena() {
    final ojo = IconButton(
      icon: Icon(
        _ocultarPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: const Color(0xFF94A3B8),
        size: 20,
      ),
      onPressed: () => setState(() => _ocultarPass = !_ocultarPass),
    );
    return Column(
      children: [
        _encabezado(
          Icons.password_rounded,
          'Nueva contraseña',
          'Crea una contraseña nueva de al menos ${Validar.minContrasena} caracteres, con letras y números.',
        ),
        TextFormField(
          key: _passKey,
          controller: _passController,
          obscureText: _ocultarPass,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          inputFormatters: Validar.formatoContrasena,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: Validar.contrasenaNueva,
          onChanged: (_) {
            if (_pass2Controller.text.isNotEmpty) _pass2Key.currentState?.validate();
          },
          style: const TextStyle(fontSize: 14, color: _oscuro),
          decoration: _decoracion('Nueva contraseña', Icons.lock_outline_rounded, sufijo: ojo),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: _pass2Key,
          controller: _pass2Controller,
          obscureText: _ocultarPass,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: Validar.formatoContrasena,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => Validar.confirmar(v, _passController.text),
          style: const TextStyle(fontSize: 14, color: _oscuro),
          decoration: _decoracion('Confirmar contraseña', Icons.lock_outline_rounded),
          onFieldSubmitted: (_) => _cambiarContrasena(),
        ),
        const SizedBox(height: 24),
        _boton('Cambiar', _cambiarContrasena),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0 && !_cargando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: AnchoMaximo(
              maximo: 480,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _oscuro, size: 20),
                          onPressed: _atras,
                        ),
                      ),
                      const Text(
                        'Recuperar contraseña',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _oscuro),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _paso ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= _paso ? _azul : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_paso),
                      child: _paso == 0
                          ? _pasoCorreo()
                          : _paso == 1
                              ? _pasoCodigo()
                              : _pasoNuevaContrasena(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}