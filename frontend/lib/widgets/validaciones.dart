import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Validar {
  static final RegExp _correo = RegExp(r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$");
  static final RegExp _nombre = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+([ '\-][a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]+)*$");

  static const int minContrasena = 6;
  static const int maxContrasena = 64;
  static const int maxNombre = 40;
  static const int maxCorreo = 100;

  static final List<TextInputFormatter> formatoNombre = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ '\-]")),
    FilteringTextInputFormatter.deny(RegExp(r'  ')),
    LengthLimitingTextInputFormatter(maxNombre),
  ];

  static final List<TextInputFormatter> formatoCorreo = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(maxCorreo),
  ];

  static final List<TextInputFormatter> formatoContrasena = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(maxContrasena),
  ];

  static String? correo(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo electrónico';
    if (v.length > maxCorreo) return 'El correo es demasiado largo';
    if (!_correo.hasMatch(v) || v.contains('..')) return 'Ingresa un correo válido (ej. nombre@correo.com)';
    return null;
  }

  static String? nombre(String? valor, {String campo = 'el nombre', bool obligatorio = true}) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return obligatorio ? 'Ingresa $campo' : null;
    if (v.length < 2) return 'Debe tener al menos 2 letras';
    if (v.length > maxNombre) return 'Máximo $maxNombre caracteres';
    if (!_nombre.hasMatch(v)) return 'Solo se permiten letras';
    return null;
  }

  static String? contrasenaLogin(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa tu contraseña';
    return null;
  }

  static String? contrasenaNueva(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (v.contains(RegExp(r'\s'))) return 'No debe contener espacios';
    if (v.length < minContrasena) return 'Mínimo $minContrasena caracteres';
    if (v.length > maxContrasena) return 'Máximo $maxContrasena caracteres';
    if (!v.contains(RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]'))) return 'Debe incluir al menos una letra';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Debe incluir al menos un número';
    return null;
  }

  static String? confirmar(String? valor, String original) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Confirma tu contraseña';
    if (v != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? codigo(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'Ingresa el código';
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'El código debe tener 6 dígitos';
    return null;
  }

  static InputBorder bordeError(double radio) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radio),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      );

  static InputBorder bordeErrorFoco(double radio) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radio),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      );

  static const TextStyle estiloError = TextStyle(fontSize: 12, color: Color(0xFFDC2626), height: 1.2);
}