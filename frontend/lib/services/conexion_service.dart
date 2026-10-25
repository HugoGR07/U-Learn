import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

class ConexionService {
  static const String mensajeSinInternet =
      'No tienes conexión a internet. Revisa tu Wi-Fi o tus datos móviles e inténtalo de nuevo.';
  static const String mensajeServidor =
      'No pudimos comunicarnos con el servidor. Inténtalo de nuevo en unos momentos.';
  static const String mensajeTiempo =
      'El servidor tardó demasiado en responder. Inténtalo de nuevo.';

  static const Duration _vigencia = Duration(seconds: 4);
  static const Duration _espera = Duration(seconds: 4);

  static DateTime? _ultimaRevision;
  static bool _ultimoResultado = true;
  static Future<bool>? _enCurso;

  static bool esMensajeDeConexion(String mensaje) =>
      mensaje == mensajeSinInternet || mensaje == mensajeServidor || mensaje == mensajeTiempo;

  static Future<bool> hayInternet({String? host, int puerto = 443}) {
    if (kIsWeb) return Future.value(true);

    final ultima = _ultimaRevision;
    if (ultima != null && _ultimoResultado && DateTime.now().difference(ultima) < _vigencia) {
      return Future.value(true);
    }

    return _enCurso ??= _revisar(host, puerto).then((ok) {
      _ultimoResultado = ok;
      _ultimaRevision = DateTime.now();
      _enCurso = null;
      return ok;
    });
  }

  static Future<bool> _revisar(String? host, int puerto) {
    final destinos = <MapEntry<String, int>>[
      if (host != null && host.isNotEmpty) MapEntry(host, puerto),
      const MapEntry('dns.google', 443),
      const MapEntry('one.one.one.one', 443),
    ];

    final completer = Completer<bool>();
    var pendientes = destinos.length;

    for (final destino in destinos) {
      Socket.connect(destino.key, destino.value, timeout: _espera).then((socket) {
        socket.destroy();
        if (!completer.isCompleted) completer.complete(true);
      }).catchError((_) {
        pendientes--;
        if (pendientes == 0 && !completer.isCompleted) completer.complete(false);
      });
    }

    return completer.future.timeout(_espera + const Duration(seconds: 1), onTimeout: () => false);
  }
}