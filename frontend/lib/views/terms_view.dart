import 'package:flutter/material.dart';

import '../legal/contenido_legal.dart';
import '../widgets/encabezado_azul.dart';
import '../widgets/responsivo.dart';

class TermsView extends StatefulWidget {
  final int pestanaInicial;
  final bool modoAceptar;
  final bool yaAceptado;

  const TermsView({
    super.key,
    this.pestanaInicial = 0,
    this.modoAceptar = false,
    this.yaAceptado = false,
  });

  @override
  State<TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<TermsView> {
  static const _azul = Color(0xFF1D61E7);
  static const _texto = Color(0xFF1E293B);
  static const _gris = Color(0xFF64748B);
  static const _borde = Color(0xFFE2E8F0);

  late int _tab = widget.pestanaInicial < 0 ? 0 : (widget.pestanaInicial > 2 ? 2 : widget.pestanaInicial);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _cambiarTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  static const _etiquetas = ['Términos', 'Privacidad', 'Derechos ARCO'];
  static const _iconos = [
    Icons.description_outlined,
    Icons.privacy_tip_outlined,
    Icons.verified_user_outlined,
  ];

  List<Widget> get _contenido => switch (_tab) {
        0 => _listaSecciones(terminos),
        1 => _listaSecciones(avisoPrivacidad),
        _ => _contenidoArco(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: context.esHorizontal ? _vistaHorizontal() : _vistaVertical(),
    );
  }

  Widget _vistaVertical() {
    return Column(
      children: [
        EncabezadoAzul(
          title: 'Términos y privacidad',
          subtitle: 'Versión ${LegalInfo.version} · ${LegalInfo.ultimaActualizacion}',
          leading: EncabezadoAzul.boton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
        ),
        AnchoMaximo(
          maximo: 760,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _selector(),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              AnchoMaximo(
                maximo: 760,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (actual, previos) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previos, if (actual != null) actual],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Column(
                      key: ValueKey(_tab),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _contenido,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.modoAceptar) _barraAceptar(),
      ],
    );
  }

  Widget _vistaHorizontal() {
    final seguro = MediaQuery.paddingOf(context);
    return Row(
      children: [
        _panelLateral(seguro),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: ListView(
              key: ValueKey(_tab),
              padding: EdgeInsets.fromLTRB(20, 16 + seguro.top, 20 + seguro.right, 20 + seguro.bottom),
              children: [
                AnchoMaximo(
                  maximo: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _etiquetas[_tab],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _texto),
                      ),
                      const SizedBox(height: 12),
                      ..._contenido,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelLateral(EdgeInsets seguro) {
    return Container(
      width: 250 + seguro.left,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1D61E7), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16 + seguro.left, 12 + seguro.top, 16, 16 + seguro.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 28 - seguro.top - seguro.bottom).clamp(0.0, double.infinity),
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      EncabezadoAzul.boton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Términos y privacidad',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Versión ${LegalInfo.version} · ${LegalInfo.ultimaActualizacion}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  for (int i = 0; i < _etiquetas.length; i++) ...[
                    _pestanaLateral(i),
                    const SizedBox(height: 8),
                  ],
                  const Spacer(),
                  if (widget.modoAceptar) ...[
                    const SizedBox(height: 12),
                    _botonAceptar(sobreAzul: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pestanaLateral(int i) {
    final activo = i == _tab;
    return GestureDetector(
      onTap: () => _cambiarTab(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: activo ? 0 : 0.2)),
        ),
        child: Row(
          children: [
            Icon(_iconos[i], size: 19, color: activo ? _azul : Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _etiquetas[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                  color: activo ? _azul : Colors.white,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: activo ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.chevron_right_rounded, size: 18, color: _azul),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selector() {
    const etiquetas = _etiquetas;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(etiquetas.length, (i) {
          final activo = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => _cambiarTab(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: activo ? Colors.white : Colors.white.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: activo ? 0.06 : 0),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  etiquetas[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                    color: activo ? _azul : _gris,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _listaSecciones(List<SeccionLegal> secciones) {
    return [
      for (final s in secciones) ...[
        _tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.titulo,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _texto),
              ),
              const SizedBox(height: 10),
              for (final b in s.bloques) _bloque(b),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _bloque(BloqueLegal b) {
    if (b.lista != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            for (final item in b.lista!)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7, right: 10),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
                    ),
                    Expanded(child: Text(item, textAlign: TextAlign.justify, style: _estiloCuerpo)),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (b.destacado) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: _azul),
            const SizedBox(width: 10),
            Expanded(
              child: Text(b.texto!, textAlign: TextAlign.justify, style: _estiloCuerpo.copyWith(color: const Color(0xFF1E3A8A))),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(b.texto!, textAlign: TextAlign.justify, style: _estiloCuerpo),
    );
  }

  static const _estiloCuerpo = TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569));

  Widget _tarjeta({required Widget child, Color borde = _borde}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde, width: 1.2),
      ),
      child: child,
    );
  }

  List<Widget> _contenidoArco() {
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text(
          'Tienes derecho a acceder, rectificar, cancelar y oponerte al tratamiento de tus datos. '
          'Así puedes ejercer cada uno:',
          textAlign: TextAlign.justify,
          style: _estiloCuerpo,
        ),
      ),
      for (final d in derechosArco) ...[
        _tarjetaDerecho(d),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 16),
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revocar tu consentimiento',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _texto)),
            const SizedBox(height: 8),
            Text(revocacionTexto, textAlign: TextAlign.justify, style: _estiloCuerpo),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cómo hacer tu solicitud por correo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _texto)),
            const SizedBox(height: 10),
            _bloque(const BloqueLegal.lista(solicitudPorCorreo)),
          ],
        ),
      ),
    ];
  }

  Widget _tarjetaDerecho(DerechoArco d) {
    return _tarjeta(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(d.letra,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _azul)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.nombre,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _texto)),
                const SizedBox(height: 2),
                Text(d.queEs, textAlign: TextAlign.justify, style: const TextStyle(fontSize: 12, color: _gris)),
                const SizedBox(height: 8),
                Text(d.comoEnLaApp, textAlign: TextAlign.justify, style: _estiloCuerpo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraAceptar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _borde)),
      ),
      child: AnchoMaximo(maximo: 760, child: _botonAceptar()),
    );
  }

  Widget _botonAceptar({bool sobreAzul = false}) {
    if (widget.yaAceptado) {
      return OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: sobreAzul ? Colors.white : null,
          side: BorderSide(color: sobreAzul ? Colors.white : _borde, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Cancelar',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _gris)),
      );
    }
    return ElevatedButton(
      onPressed: () => Navigator.pop(context, true),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: sobreAzul ? Colors.white : _azul,
        foregroundColor: sobreAzul ? _azul : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text('He leído y acepto',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}