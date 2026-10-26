import 'package:flutter/material.dart';

extension Responsivo on BuildContext {
  bool get esHorizontal => MediaQuery.orientationOf(this) == Orientation.landscape;
}

class AnchoMaximo extends StatelessWidget {
  final double maximo;
  final Widget child;

  const AnchoMaximo({super.key, this.maximo = 620, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final disponible = constraints.hasBoundedWidth ? constraints.maxWidth : maximo;
        final ancho = disponible < maximo ? disponible : maximo;
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: SizedBox(width: ancho, child: child),
        );
      },
    );
  }
}

class EspacioTeclado extends StatelessWidget {
  final Widget child;

  const EspacioTeclado({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}

class CentradoDesplazable extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CentradoDesplazable({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = padding.resolve(Directionality.of(context)).vertical;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - vertical).clamp(0.0, double.infinity),
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}