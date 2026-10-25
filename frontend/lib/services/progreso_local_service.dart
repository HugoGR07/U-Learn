import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class ProgresoLocalService {
  static String _clave(int idSeccion) {
    final usuario = ApiService.currentUser?['id_usuario'] ?? ApiService.currentUser?['correo'] ?? 'anonimo';
    return 'ul_temas_vistos_${usuario}_$idSeccion';
  }

  static Future<Set<int>> vistos(int idSeccion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_clave(idSeccion)) ?? const [];
      return lista.map(int.tryParse).whereType<int>().toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> marcarVisto(int idSeccion, int indice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actuales = (prefs.getStringList(_clave(idSeccion)) ?? const []).toSet();
      if (actuales.add('$indice')) {
        await prefs.setStringList(_clave(idSeccion), actuales.toList());
      }
    } catch (_) {}
  }

  static int primerPendiente(Set<int> vistos, int total) {
    for (int i = 0; i < total; i++) {
      if (!vistos.contains(i)) return i;
    }
    return -1;
  }
}