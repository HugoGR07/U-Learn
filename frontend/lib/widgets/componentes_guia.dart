import 'package:flutter/material.dart';

class IconosFinanzas {
  static const List<IconData> ciclo = [
    Icons.savings_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.trending_up_rounded,
    Icons.pie_chart_rounded,
    Icons.receipt_long_rounded,
    Icons.calculate_rounded,
    Icons.payments_rounded,
    Icons.account_balance_rounded,
  ];

  static IconData para(String texto, int indice) {
    final t = texto.toLowerCase();
    if (t.contains('ahorr')) return Icons.savings_rounded;
    if (t.contains('interés') || t.contains('interes') || t.contains('tasa') || t.contains('%')) {
      return Icons.percent_rounded;
    }
    if (t.contains('deuda') || t.contains('préstamo') || t.contains('prestamo')) return Icons.money_off_rounded;
    if (t.contains('tarjeta') || t.contains('crédito') || t.contains('credito')) return Icons.credit_card_rounded;
    if (t.contains('presupuesto') || t.contains('cálculo') || t.contains('calcul')) return Icons.calculate_rounded;
    if (t.contains('invers') || t.contains('rendimiento') || t.contains('crecer')) return Icons.trending_up_rounded;
    if (t.contains('gasto') || t.contains('compra') || t.contains('consumo')) return Icons.shopping_cart_rounded;
    if (t.contains('ingreso') || t.contains('salario') || t.contains('sueldo')) return Icons.payments_rounded;
    if (t.contains('banco') || t.contains('cuenta')) return Icons.account_balance_rounded;
    if (t.contains('seguro') || t.contains('riesgo') || t.contains('emergencia') || t.contains('protec')) {
      return Icons.shield_rounded;
    }
    if (t.contains('meta') || t.contains('objetivo') || t.contains('plan')) return Icons.flag_rounded;
    if (t.contains('hábito') || t.contains('habito') || t.contains('emoci')) return Icons.self_improvement_rounded;
    return ciclo[indice % ciclo.length];
  }
}

class TextoConDinero extends StatelessWidget {
  final String texto;
  final Color acento;
  final double tamano;
  final Color color;
  final TextAlign alineacion;
  final FontWeight peso;
  final double altura;

  const TextoConDinero(
    this.texto, {
    super.key,
    required this.acento,
    this.tamano = 14,
    this.color = const Color(0xFF334155),
    this.alineacion = TextAlign.justify,
    this.peso = FontWeight.normal,
    this.altura = 1.55,
  });

  static final RegExp _patron = RegExp(
    r'((?:MXN\s?)?\$\s?\d(?:[\d,\.]*\d)?(?:\s?(?:mil(?:lones)?|millón))?(?:\s?(?:MXN|pesos))?|\d(?:[\d,\.]*\d)?(?:\s?(?:mil(?:lones)?|millón))?\s?(?:MXN|pesos)|\d+(?:[\.,]\d+)?\s?%)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: tamano, color: color, height: altura, fontWeight: peso);
    final resaltado = base.copyWith(
      fontWeight: FontWeight.w800,
      color: acento,
      backgroundColor: acento.withValues(alpha: 0.16),
    );

    final partes = <TextSpan>[];
    var inicio = 0;
    for (final m in _patron.allMatches(texto)) {
      if (m.start > inicio) partes.add(TextSpan(text: texto.substring(inicio, m.start)));
      partes.add(TextSpan(text: '\u2009${m.group(0)}\u2009', style: resaltado));
      inicio = m.end;
    }
    if (inicio < texto.length) partes.add(TextSpan(text: texto.substring(inicio)));

    return Text.rich(TextSpan(style: base, children: partes), textAlign: alineacion);
  }
}

class Aparecer extends StatefulWidget {
  final int orden;
  final Widget child;
  final Duration duracion;
  final int pasoMs;
  final double desplazamiento;

  const Aparecer({
    super.key,
    required this.orden,
    required this.child,
    this.duracion = const Duration(milliseconds: 520),
    this.pasoMs = 70,
    this.desplazamiento = 24,
  });

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duracion);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: widget.pasoMs * widget.orden.clamp(0, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, widget.desplazamiento * (1 - _a.value)),
          child: Transform.scale(scale: 0.97 + 0.03 * _a.value, child: child),
        ),
      ),
    );
  }
}

class EtiquetaSeccion extends StatelessWidget {
  final IconData icono;
  final String texto;

  const EtiquetaSeccion({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF2FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, size: 16, color: const Color(0xFF1D61E7)),
        ),
        const SizedBox(width: 10),
        Text(
          texto,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}