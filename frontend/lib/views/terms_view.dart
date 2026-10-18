import 'package:flutter/material.dart';

import '../legal/contenido_legal.dart';
import '../widgets/encabezado_azul.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          EncabezadoAzul(
            title: 'Términos y privacidad',
            subtitle: 'Versión ${LegalInfo.version} · ${LegalInfo.ultimaActualizacion}',
            leading: EncabezadoAzul.boton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _selector(),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: switch (_tab) {
                0 => _listaSecciones(terminos),
                1 => _listaSecciones(avisoPrivacidad),
                _ => _contenidoArco(),
              },
            ),
          ),
          if (widget.modoAceptar) _barraAceptar(),
        ],
      ),
    );
  }

  Widget _selector() {
    const etiquetas = ['Términos', 'Privacidad', 'Derechos ARCO'];
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
                  color: activo ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: activo
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
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
      child: widget.yaAceptado
          ? OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: _borde, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancelar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _gris)),
            )
          : ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: _azul,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('He leído y acepto',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}