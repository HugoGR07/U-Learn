import 'package:flutter/material.dart';

class FotoPerfil extends StatelessWidget {
  static const int total = 10;

  static String ruta(int numero) => 'assets/images/perfiles/perfil_$numero.png';

  static int? desdeUsuario(Map<String, dynamic>? user) {
    final valor = user?['foto_perfil'];
    final numero = valor is int ? valor : int.tryParse('${valor ?? ''}');
    if (numero == null || numero < 1 || numero > total) return null;
    return numero;
  }

  final int? numero;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;

  const FotoPerfil({
    super.key,
    required this.numero,
    required this.size,
    this.backgroundColor = const Color(0xFFFDBA74),
    this.iconColor = Colors.white,
    this.icon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.6, color: iconColor),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: numero == null
            ? fallback
            : Image.asset(
                ruta(numero!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}