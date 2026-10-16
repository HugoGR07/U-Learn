import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://ulearnbackend.vercel.app/api',
  );
  static String? token; // Guardará el JWT tras el login
  static Map<String, dynamic>? currentUser;

  // 1. REGISTRO DE USUARIO
  static Future<Map<String, dynamic>> register({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'apellido_paterno': apellidoPaterno,
          'apellido_materno': apellidoMaterno,
          'correo': correo,
          'contrasena': contrasena,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al registrar'};
      }
    } catch (e) {
      return {'success': false, 'message': 'No se pudo conectar con el servidor'};
    }
  }

  // 2. INICIO DE SESIÓN
  static Future<Map<String, dynamic>> login({
    required String correo,
    required String contrasena,
  }) async {
    try {
        final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
            'correo': correo,
            'contrasena': contrasena,
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          token = data['token']; // Almacenar Token JWT
          currentUser = data['user']; // Almacenar información del usuario
          return {'success': true, 'user': currentUser};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Error al iniciar sesión'};
        }
    } catch (e){
      return {'success': false, 'message': 'No se pudo conectar con el servidor:{$e}'};
    }
  }

  // 3. OBTENER TEMAS DE LA BASE DE DATOS
  static Future<List<dynamic>> getTopics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/guides/topics'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['temas'] ?? [];
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Error (${response.statusCode}) al cargar temas');
    }
  }

  // 4. OBTENER LOS CURSOS/GUÍAS DEL USUARIO
  static Future<List<dynamic>> getUserGuides() async {
    final response = await http.get(
      Uri.parse('$baseUrl/guides/my-guides'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['guias'] ?? [];
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Error (${response.statusCode}) al consultar guías');
    }
  }

  // Actualizar información personal
  static Future<Map<String, dynamic>> updateProfile({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/update-profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nombre': nombre,
          'apellido_paterno': apellidoPaterno,
          'apellido_materno': apellidoMaterno,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        currentUser = data['user']; // Actualizar datos locales del usuario
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al actualizar'};
      }
    } catch (e) {
      return {'success': false, 'message': 'No se pudo conectar con el servidor'};
    }
  }

  // Cambiar contraseña en la base de datos
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al cambiar contraseña'};
      }
    } catch (e) {
      return {'success': false, 'message': 'No se pudo conectar con el servidor'};
    }
  }

  /// Método para generar un nuevo curso / guía de estudio mediante la API de Gemini
  static Future<Map<String, dynamic>> generateCourse(String tema, {String nivel = 'Intermedio'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guides/generate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tema': tema,
          'nivel': nivel,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Curso generado exitosamente',
          'id_guia': data['id_guia'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al generar la guía de estudio',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor',
      };
    }
  }

  /// Obtener el detalle completo de un curso/guía por su ID
  static Future<Map<String, dynamic>> getGuideDetails(int idGuia) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guides/details/$idGuia'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al obtener curso'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión con el servidor'};
    }
  }

  /// Marcar una sección como completada
  static Future<bool> completeSection(int idSeccion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guides/complete-section'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id_seccion': idSeccion}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

    /// Registrar que el usuario abrió/empezó una sección
  static Future<bool> startSection(int idSeccion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guides/start-section'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id_seccion': idSeccion}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> completeSectionExam(
      int examId, List<Map<String, dynamic>> respuestas) async {
    try {
      // Usamos el parámetro examId exactamente como se definió arriba
      final url = Uri.parse('$baseUrl/exam/$examId/submit');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Asegúrate de enviar el token JWT si tu backend tiene authMiddleware
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'respuestas': respuestas,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Error ${response.statusCode}: No se pudo enviar el examen',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }


  static Future<bool?> getNotificationSettings() async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/auth/notification-settings'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body)['notif_correo'] as bool?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateNotificationSettings({required bool emailAlerts}) async {
    try {
      final r = await http.put(
        Uri.parse('$baseUrl/auth/notification-settings'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'notif_correo': emailAlerts}),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}