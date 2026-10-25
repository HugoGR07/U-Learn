import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_service.dart';
import 'conexion_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://ulearnbackend.vercel.app/api',
  );
  static String? token; // Guardará el JWT tras el login
  static Map<String, dynamic>? currentUser;

  static void Function()? onSessionExpired;

  static const String mensajeSesionExpirada = 'Tu sesión expiró. Inicia sesión de nuevo para continuar.';
  static const String _mensajeLimite = 'Hiciste demasiadas solicitudes seguidas. Espera un momento e inténtalo de nuevo.';
  static const String _mensajeIA =
      'La inteligencia artificial está muy solicitada en este momento. Espera un par de minutos e inténtalo de nuevo.';

  static const Duration _tiempoNormal = Duration(seconds: 30);
  static const Duration _tiempoGeneracion = Duration(minutes: 5);
  static const Duration _tiempoTutor = Duration(seconds: 90);

  static String mensajeDe(Object error, {String porDefecto = ConexionService.mensajeServidor}) =>
      error is ApiException ? error.message : porDefecto;

  static Future<bool> hayInternet() {
    final uri = Uri.parse(baseUrl);
    return ConexionService.hayInternet(host: uri.host, puerto: uri.port);
  }

  static Map<String, String> _headers({bool conToken = true}) => {
        'Content-Type': 'application/json',
        if (conToken && token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> _enviar(
    Future<http.Response> Function() peticion, {
    Duration tiempo = _tiempoNormal,
  }) async {
    if (!await hayInternet()) {
      throw const ApiException(ConexionService.mensajeSinInternet);
    }
    try {
      return await peticion().timeout(tiempo);
    } on TimeoutException {
      throw const ApiException(ConexionService.mensajeTiempo);
    } catch (_) {
      if (!await hayInternet()) {
        throw const ApiException(ConexionService.mensajeSinInternet);
      }
      throw const ApiException(ConexionService.mensajeServidor);
    }
  }

  static Map<String, dynamic> _json(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static String _mensaje(http.Response response, Map<String, dynamic> data, String porDefecto) {
    final status = response.statusCode;
    final texto = data['message'] is String ? (data['message'] as String).trim() : '';
    if (status == 429) return texto.isNotEmpty ? texto : _mensajeLimite;
    if (status == 503) return texto.isNotEmpty ? texto : _mensajeIA;
    if (status >= 500) return porDefecto;
    return texto.isNotEmpty ? texto : porDefecto;
  }

  static Future<bool> _sesionInvalida(http.Response response) async {
    if (token == null) return false;
    if (response.statusCode != 401 && response.statusCode != 403) return false;
    await logout();
    onSessionExpired?.call();
    return true;
  }

  static Future<bool> restoreSession() async {
    final saved = await SessionService.load();
    if (saved == null) return false;

    token = saved.token;
    currentUser = saved.user;
    _validarSesionConServidor();
    return true;
  }

  static Future<void> _validarSesionConServidor() async {
    try {
      if (!await hayInternet()) return;
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = _json(response);
        if (data['user'] is Map) {
          currentUser = Map<String, dynamic>.from(data['user']);
          await SessionService.saveUser(currentUser!);
        }
        if (data['token'] is String) {
          token = data['token'];
          await SessionService.saveToken(token!);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        onSessionExpired?.call();
      }
    } catch (_) {}
  }

  static Future<void> logout() async {
    token = null;
    currentUser = null;
    await SessionService.clear();
  }

  // 1. REGISTRO DE USUARIO
  static Future<Map<String, dynamic>> register({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final response = await _enviar(() => http.post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers(conToken: false),
            body: jsonEncode({
              'nombre': nombre,
              'apellido_paterno': apellidoPaterno,
              'apellido_materno': apellidoMaterno,
              'correo': correo,
              'contrasena': contrasena,
            }),
          ));

      final data = _json(response);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudo crear tu cuenta. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  // 2. INICIO DE SESIÓN
  static Future<Map<String, dynamic>> login({
    required String correo,
    required String contrasena,
  }) async {
    try {
      final response = await _enviar(() => http.post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers(conToken: false),
            body: jsonEncode({
              'correo': correo,
              'contrasena': contrasena,
            }),
          ));

      final data = _json(response);
      if (response.statusCode == 200 && data['token'] is String) {
        token = data['token']; // Almacenar Token JWT
        currentUser = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null; // Almacenar información del usuario
        await SessionService.save(token!, currentUser);
        return {'success': true, 'user': currentUser};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudo iniciar sesión. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  // 3. OBTENER TEMAS DE LA BASE DE DATOS
  static Future<List<dynamic>> getTopics() async {
    final response = await _enviar(() => http.get(
          Uri.parse('$baseUrl/guides/topics'),
          headers: _headers(),
        ));

    final data = _json(response);
    if (response.statusCode == 200) {
      return (data['temas'] as List?) ?? [];
    }
    if (await _sesionInvalida(response)) {
      throw ApiException(mensajeSesionExpirada, statusCode: response.statusCode);
    }
    throw ApiException(
      _mensaje(response, data, 'No pudimos cargar los temas. Inténtalo de nuevo.'),
      statusCode: response.statusCode,
    );
  }

  // 4. OBTENER LOS CURSOS/GUÍAS DEL USUARIO
  static Future<List<dynamic>> getUserGuides() async {
    final response = await _enviar(() => http.get(
          Uri.parse('$baseUrl/guides/my-guides'),
          headers: _headers(),
        ));

    final data = _json(response);
    if (response.statusCode == 200) {
      return (data['guias'] as List?) ?? [];
    }
    if (await _sesionInvalida(response)) {
      throw ApiException(mensajeSesionExpirada, statusCode: response.statusCode);
    }
    throw ApiException(
      _mensaje(response, data, 'No pudimos cargar tus guías. Inténtalo de nuevo.'),
      statusCode: response.statusCode,
    );
  }

  // Actualizar información personal
  static Future<Map<String, dynamic>> updateProfile({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
  }) async {
    try {
      final response = await _enviar(() => http.put(
            Uri.parse('$baseUrl/auth/update-profile'),
            headers: _headers(),
            body: jsonEncode({
              'nombre': nombre,
              'apellido_paterno': apellidoPaterno,
              'apellido_materno': apellidoMaterno,
            }),
          ));

      final data = _json(response);
      if (response.statusCode == 200) {
        if (data['user'] is Map) {
          currentUser = Map<String, dynamic>.from(data['user']); // Actualizar datos locales del usuario
          await SessionService.saveUser(currentUser!);
        }
        return {'success': true, 'message': data['message']};
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudieron actualizar tus datos. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  static Future<Map<String, dynamic>> updateProfilePhoto(int fotoPerfil) async {
    try {
      final response = await _enviar(() => http.put(
            Uri.parse('$baseUrl/auth/profile-photo'),
            headers: _headers(),
            body: jsonEncode({'foto_perfil': fotoPerfil}),
          ));

      final data = _json(response);
      if (response.statusCode == 200) {
        if (data['user'] is Map) {
          currentUser = Map<String, dynamic>.from(data['user']);
          await SessionService.saveUser(currentUser!);
        }
        return {'success': true, 'message': data['message']};
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudo guardar tu foto. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  // Cambiar contraseña en la base de datos
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _enviar(() => http.put(
            Uri.parse('$baseUrl/auth/change-password'),
            headers: _headers(),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          ));

      final data = _json(response);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudo cambiar la contraseña. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  /// Método para generar un nuevo curso / guía de estudio mediante la API de Gemini
  static Future<Map<String, dynamic>> generateCourse(
    String tema, {
    String nivel = 'Intermedio',
    int duracionSemanas = 4,
  }) async {
    try {
      final response = await _enviar(
        () => http.post(
          Uri.parse('$baseUrl/guides/generate'),
          headers: _headers(),
          body: jsonEncode({
            'tema': tema,
            'nivel': nivel,
            'duracion_semanas': duracionSemanas,
          }),
        ),
        tiempo: _tiempoGeneracion,
      );

      final data = _json(response);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Curso generado exitosamente',
          'id_guia': data['id_guia'],
        };
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(
          response,
          data,
          'No se pudo generar tu guía en este momento. Inténtalo de nuevo en unos minutos.',
        ),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  /// Obtener el detalle completo de un curso/guía por su ID
  static Future<Map<String, dynamic>> getGuideDetails(int idGuia) async {
    try {
      final response = await _enviar(() => http.get(
            Uri.parse('$baseUrl/guides/details/$idGuia'),
            headers: _headers(),
          ));

      final data = _json(response);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No pudimos abrir tu guía. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  static Future<Map<String, dynamic>> deleteGuide(int idGuia) async {
    try {
      final response = await _enviar(() => http.delete(
            Uri.parse('$baseUrl/guides/$idGuia'),
            headers: _headers(),
          ));

      final data = _json(response);
      if (response.statusCode == 200 || response.statusCode == 404) {
        return {'success': true, 'message': data['message']};
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudo eliminar la guía. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  /// Marcar una sección como completada
  static Future<bool> completeSection(int idSeccion) async {
    try {
      final response = await _enviar(() => http.post(
            Uri.parse('$baseUrl/guides/complete-section'),
            headers: _headers(),
            body: jsonEncode({'id_seccion': idSeccion}),
          ));
      if (response.statusCode == 200) return true;
      await _sesionInvalida(response);
      return false;
    } on ApiException {
      return false;
    }
  }

  /// Registrar que el usuario abrió/empezó una sección
  static Future<bool> startSection(int idSeccion) async {
    try {
      final response = await _enviar(() => http.post(
            Uri.parse('$baseUrl/guides/start-section'),
            headers: _headers(),
            body: jsonEncode({'id_seccion': idSeccion}),
          ));
      return response.statusCode == 200;
    } on ApiException {
      return false;
    }
  }

  static Future<Map<String, dynamic>> completeSectionExam(
      int examId, List<Map<String, dynamic>> respuestas) async {
    try {
      // Usamos el parámetro examId exactamente como se definió arriba
      final url = Uri.parse('$baseUrl/exam/$examId/submit');

      final response = await _enviar(() => http.post(
            url,
            headers: _headers(),
            body: jsonEncode({
              'respuestas': respuestas,
            }),
          ));

      final data = _json(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      if (await _sesionInvalida(response)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(response, data, 'No se pudo enviar tu examen. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  static Future<bool?> getNotificationSettings() async {
    try {
      final r = await _enviar(() => http.get(
            Uri.parse('$baseUrl/auth/notification-settings'),
            headers: _headers(),
          ));
      if (r.statusCode != 200) return null;
      final valor = _json(r)['notif_correo'];
      return valor is bool ? valor : null;
    } on ApiException {
      return null;
    }
  }

  static Future<bool> updateNotificationSettings({required bool emailAlerts}) async {
    final res = await updateNotificationSettingsDetallado(emailAlerts: emailAlerts);
    return res['success'] == true;
  }

  static Future<Map<String, dynamic>> updateNotificationSettingsDetallado({required bool emailAlerts}) async {
    try {
      final r = await _enviar(() => http.put(
            Uri.parse('$baseUrl/auth/notification-settings'),
            headers: _headers(),
            body: jsonEncode({'notif_correo': emailAlerts}),
          ));
      if (r.statusCode == 200) return {'success': true};
      if (await _sesionInvalida(r)) {
        return {'success': false, 'message': mensajeSesionExpirada};
      }
      return {
        'success': false,
        'message': _mensaje(r, _json(r), 'No se pudo guardar tu preferencia. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  // TUTOR IA
  static Future<String> askAiTutor({
    required String prompt,
    required List<Map<String, dynamic>> examenCompleto,
    required List<Map<String, dynamic>> errores,
  }) async {
    final res = await _consultarTutor(
      prompt: prompt,
      examenCompleto: examenCompleto,
      errores: errores,
    );
    return res['respuesta']?.toString() ?? '';
  }

  /// Tutor IA con respuesta estructurada.
  /// Devuelve {'fundamentos': Map? , 'respuesta': String}.
  static Future<Map<String, dynamic>> askAiTutorDetallado({
    required List<Map<String, dynamic>> examenCompleto,
    required List<Map<String, dynamic>> errores,
  }) async {
    final data = await _consultarTutor(
      prompt: 'Fundamento teórico de los errores del examen',
      examenCompleto: examenCompleto,
      errores: errores,
    );
    return {
      'fundamentos': data['fundamentos'] is Map
          ? Map<String, dynamic>.from(data['fundamentos'])
          : null,
      'respuesta': data['respuesta']?.toString() ?? '',
    };
  }

  static Future<Map<String, dynamic>> _consultarTutor({
    required String prompt,
    required List<Map<String, dynamic>> examenCompleto,
    required List<Map<String, dynamic>> errores,
  }) async {
    final response = await _enviar(
      () => http.post(
        Uri.parse('$baseUrl/exam/tutor-ia'),
        headers: _headers(),
        body: jsonEncode({
          'prompt': prompt,
          'examen_completo': examenCompleto,
          'errores': errores,
        }),
      ),
      tiempo: _tiempoTutor,
    );

    final data = _json(response);
    if (response.statusCode == 200) return data;
    if (await _sesionInvalida(response)) {
      throw ApiException(mensajeSesionExpirada, statusCode: response.statusCode);
    }
    throw ApiException(
      _mensaje(response, data, 'El tutor no pudo responder en este momento. Inténtalo de nuevo.'),
      statusCode: response.statusCode,
    );
  }

  // RECUPERACIÓN DE CONTRASEÑA (rutas públicas, sin token)
  static Future<Map<String, dynamic>> _postPublico(String ruta, Map<String, dynamic> body) async {
    try {
      final response = await _enviar(() => http.post(
            Uri.parse('$baseUrl$ruta'),
            headers: _headers(conToken: false),
            body: jsonEncode(body),
          ));
      final data = _json(response);
      final ok = response.statusCode == 200;
      return {
        'success': ok,
        'message': ok
            ? (data['message'] ?? 'Listo')
            : _mensaje(response, data, 'Ocurrió un problema. Inténtalo de nuevo.'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message, 'conexion': true};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String correo) =>
      _postPublico('/auth/forgot-password', {'correo': correo});

  static Future<Map<String, dynamic>> verifyResetCode(String correo, String codigo) =>
      _postPublico('/auth/verify-reset-code', {'correo': correo, 'codigo': codigo});

  static Future<Map<String, dynamic>> resetPassword({
    required String correo,
    required String codigo,
    required String nuevaContrasena,
  }) =>
      _postPublico('/auth/reset-password', {
        'correo': correo,
        'codigo': codigo,
        'nuevaContrasena': nuevaContrasena,
      });
}