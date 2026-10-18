class LegalInfo {
  static const String responsable = 'Equipo Syncore, desarrollador de U-Learn';
  static const String domicilio = '[PENDIENTE: domicilio para recibir notificaciones]';
  static const String correoPrivacidad = 'carlosfranciscofel@gmail.com';
  static const String ultimaActualizacion = '17 de octubre de 2026';
  static const String version = '1.0';
}

class BloqueLegal {
  final String? texto;
  final List<String>? lista;
  final bool destacado;

  const BloqueLegal.parrafo(String t)
      : texto = t,
        lista = null,
        destacado = false;
  const BloqueLegal.lista(List<String> l)
      : texto = null,
        lista = l,
        destacado = false;
  const BloqueLegal.nota(String t)
      : texto = t,
        lista = null,
        destacado = true;
}

class SeccionLegal {
  final String titulo;
  final List<BloqueLegal> bloques;
  const SeccionLegal(this.titulo, this.bloques);
}

const List<SeccionLegal> terminos = [
  SeccionLegal('1. Qué es U-Learn', [
    BloqueLegal.parrafo(
        'U-Learn es una aplicación de educación financiera. Eliges un tema del catálogo '
        '(por ejemplo, Tarjetas de Crédito) más el tiempo, '
        'y la app genera una guía de estudio con secciones, temas y un examen de 10 preguntas por sección.'),
    BloqueLegal.parrafo(
        'Las guías, los exámenes y las explicaciones del tutor se generan con inteligencia artificial '
        '(modelos Gemini de Google). U-Learn no cobra por su uso ni tiene compras dentro de la app.'),
  ]),
  SeccionLegal('2. Tu cuenta', [
    BloqueLegal.lista([
      'Para registrarte necesitas: nombre, apellido paterno, correo electrónico y una contraseña de al menos 6 caracteres. El apellido materno es opcional.',
      'Un correo solo puede tener una cuenta.',
      'Eres responsable de mantener tu contraseña en secreto y de lo que se haga con tu sesión.',
      'Tu sesión dura 7 días en el teléfono; después tendrás que iniciar sesión de nuevo.',
      'Si olvidas tu contraseña, te enviamos un código de 6 dígitos a tu correo. Vence en 15 minutos y permite 5 intentos.',
    ]),
  ]),
  SeccionLegal('3. El contenido generado con IA', [
    BloqueLegal.nota(
        'El contenido de U-Learn es educativo. No es asesoría financiera, fiscal, legal ni de inversión, '
        'y no sustituye la opinión de un profesional.'),
    BloqueLegal.parrafo(
        'La inteligencia artificial puede cometer errores, dar datos desactualizados o explicaciones '
        'imprecisas. Los ejemplos con cifras en pesos mexicanos son ilustrativos. Verifica la información '
        'antes de tomar decisiones con tu dinero.'),
  ]),
  SeccionLegal('4. Límites de uso', [
    BloqueLegal.parrafo('Para que el servicio funcione para todos, actualmente aplicamos estos límites:'),
    BloqueLegal.lista([
      'Hasta 5 guías generadas por cuenta cada 24 horas.',
      'Hasta 20 consultas al tutor de IA por cuenta cada hora.',
      'Hasta 10 intentos cada 15 minutos para recuperar la contraseña.',
    ]),
    BloqueLegal.parrafo('Estos límites pueden ajustarse; si cambian, actualizaremos este apartado.'),
  ]),
  SeccionLegal('5. Exámenes y progreso', [
    BloqueLegal.parrafo(
        'Los exámenes se califican automáticamente. Guardamos cada intento con su número, su '
        'calificación, la fecha y la opción que elegiste en cada pregunta, y registramos cuándo '
        'empiezas y terminas cada sección para mostrarte tu avance.'),
  ]),
  SeccionLegal('6. Uso aceptable', [
    BloqueLegal.parrafo('Al usar U-Learn te comprometes a no:'),
    BloqueLegal.lista([
      'Intentar entrar a la cuenta de otra persona.',
      'Automatizar solicitudes para saltarte los límites de uso.',
      'Interferir con el funcionamiento del servidor o de la app.',
    ]),
  ]),
  SeccionLegal('7. Disponibilidad', [
    BloqueLegal.parrafo(
        'U-Learn depende de servicios externos (Google Gemini, el servidor y la base de datos). '
        'Si alguno falla, la generación de guías o el tutor pueden no estar disponibles temporalmente. '
        'No garantizamos que el servicio esté disponible sin interrupciones.'),
  ]),
  SeccionLegal('8. Menores de edad', [
    BloqueLegal.parrafo(
        'Si eres menor de 18 años, usa U-Learn con la autorización de tu madre, padre o tutor.'),
  ]),
  SeccionLegal('9. Terminar el uso', [
    BloqueLegal.parrafo(
        'Puedes dejar de usar U-Learn cuando quieras y solicitar la eliminación de tu cuenta '
        'como se explica en la pestaña "Derechos ARCO".'),
  ]),
  SeccionLegal('10. Cambios a estos términos', [
    BloqueLegal.parrafo(
        'Si cambiamos estos términos, publicaremos la nueva versión en esta misma pantalla con su '
        'fecha de actualización.'),
  ]),
];

const List<SeccionLegal> avisoPrivacidad = [
  SeccionLegal('Responsable', [
    BloqueLegal.parrafo(
        'Este aviso se emite conforme a la Ley Federal de Protección de Datos Personales en Posesión '
        'de los Particulares (DOF, 20 de marzo de 2025).'),
    BloqueLegal.lista([
      'Responsable: ${LegalInfo.responsable}',
      //'Domicilio: ${LegalInfo.domicilio}',
      //'Contacto de privacidad: ${LegalInfo.correoPrivacidad}',
    ]),
  ]),
  SeccionLegal('Datos que guardamos en el servidor', [
    BloqueLegal.lista([
      'Identificación y contacto: nombre, apellido paterno, apellido materno (opcional) y correo electrónico.',
      'Contraseña: solo se guarda cifrada con bcrypt (hash). Nadie, ni el equipo, puede leerla.',
      'Foto de perfil: el número de la imagen de perfil que elegiste de entre 10 imágenes de la app. No subimos fotos tuyas.',
      'Fecha de registro.',
      'Guías: el tema elegido y la fecha en que se generó cada guía.',
      'Avance: qué secciones empezaste y completaste, con fecha y hora.',
      'Exámenes: número de intento, calificación, fecha y la opción que elegiste en cada pregunta.',
      'Preferencia de resumen semanal por correo (activado o desactivado).',
      'Códigos de recuperación de contraseña: solo cifrados, vencen en 15 minutos.',
    ]),
    BloqueLegal.nota(
        'No recabamos datos personales sensibles. Tampoco pedimos datos financieros: ni ingresos, '
        'ni cuentas bancarias, ni tarjetas. La app no accede a tu ubicación, contactos, cámara, '
        'galería ni micrófono; el único permiso que solicita es el de notificaciones.'),
  ]),
  SeccionLegal('Datos que se quedan solo en tu teléfono', [
    BloqueLegal.lista([
      'Tu sesión (token) y una copia de tu nombre, correo y foto de perfil, en almacenamiento cifrado del sistema (Keychain en iOS, almacenamiento cifrado en Android).',
      'La bandeja de notificaciones de la app y tus preferencias de notificaciones push y recordatorios.',
    ]),
    BloqueLegal.parrafo('Estos datos no se envían al servidor.'),
  ]),
  SeccionLegal('Para qué usamos tus datos', [
    BloqueLegal.parrafo('Finalidades necesarias para darte el servicio:'),
    BloqueLegal.lista([
      'Crear tu cuenta, iniciar sesión y mantenerla segura.',
      'Generar tus guías de estudio y exámenes.',
      'Calificar tus exámenes y mostrarte tu progreso.',
      'Explicarte tus errores con el tutor de IA.',
      'Enviarte el código para recuperar tu contraseña.',
    ]),
    BloqueLegal.parrafo('Finalidad secundaria (puedes negarte sin perder el servicio):'),
    BloqueLegal.lista([
      'Enviarte cada lunes un resumen de tu progreso por correo. Se desactiva en Perfil → Notificaciones → Alertas por Correo.',
    ]),
    BloqueLegal.parrafo('No usamos tus datos para publicidad ni para crear perfiles comerciales.'),
  ]),
  SeccionLegal('Con quién se comparten', [
    BloqueLegal.parrafo(
        'No vendemos ni transferimos tus datos a terceros. La app no incluye herramientas de '
        'publicidad ni de analítica. Para funcionar usamos estos proveedores, que tratan datos '
        'por cuenta nuestra:'),
    BloqueLegal.lista([
      'Google (API de Gemini): recibe el tema elegido y el tiempo para generar la guía. Para el tutor recibe las preguntas que fallaste, la opción que elegiste y la correcta. Nunca recibe tu nombre ni tu correo.',
      'Google (Gmail): envía los correos de recuperación y el resumen semanal; recibe tu correo, tu nombre y el contenido del mensaje.',
      'Vercel: aloja el servidor. Sus registros técnicos de errores pueden incluir tu correo cuando falla un envío.',
      'Supabase: Proveedor de base de datos PostgreSQL en la nube, al que el servidor se conecta con cifrado SSL.',
    ]),
  ]),
  SeccionLegal('Cómo protegemos tus datos', [
    BloqueLegal.lista([
      'La app se comunica con el servidor por HTTPS.',
      'Las contraseñas y los códigos de recuperación se guardan cifrados con bcrypt.',
      'Tus datos personales, tu lista de guías, tu avance y tus calificaciones solo se entregan a una sesión iniciada con tu cuenta.',
      'Hay un límite de intentos para la recuperación de contraseña.',
    ]),
  ]),
  SeccionLegal('Cuánto tiempo los conservamos', [
    BloqueLegal.parrafo(
        'Mientras tu cuenta exista. Si solicitas la cancelación, borraremos tu usuario, tus guías con '
        'sus secciones, lecciones y exámenes, tu avance, tus intentos y respuestas, y tus códigos de '
        'recuperación, dentro de los plazos de la ley. Al cerrar sesión se borran del teléfono tu sesión '
        'y la copia de tus datos.'),
    BloqueLegal.parrafo(
        'Los códigos de recuperación se borran al usarse o al pedir uno nuevo. Las copias de seguridad '
        'que conserven los proveedores de infraestructura se rigen por sus propios plazos.'),
  ]),
  SeccionLegal('Tus derechos', [
    BloqueLegal.parrafo(
        'Puedes ejercer tus derechos de Acceso, Rectificación, Cancelación y Oposición (ARCO) y revocar '
        'tu consentimiento. Consulta cómo en la pestaña "Derechos ARCO".'),
  ]),
  SeccionLegal('Consentimiento y cambios', [
    BloqueLegal.parrafo(
        'Al marcar la casilla de aceptación en el registro, consientes el tratamiento descrito aquí. '
        'Si este aviso cambia, publicaremos la nueva versión en esta pantalla con su fecha.'),
  ]),
];

class DerechoArco {
  final String letra;
  final String nombre;
  final String queEs;
  final String comoEnLaApp;
  const DerechoArco(this.letra, this.nombre, this.queEs, this.comoEnLaApp);
}

const List<DerechoArco> derechosArco = [
  DerechoArco(
    'A',
    'Acceso',
    'Saber qué datos tuyos tenemos.',
    'En Perfil ves tu nombre, correo y foto, y en la pantalla principal tus guías y tu avance. '
        'Para recibir una copia completa de todo lo que guardamos, solicítala por correo.',
  ),
  DerechoArco(
    'R',
    'Rectificación',
    'Corregir datos inexactos o incompletos.',
    'Cambia tu nombre y apellidos en Perfil → Información personal. El correo no se puede cambiar desde la app: '
        'elimina tu cuenta y regístrate con el nuevo.',
  ),
  DerechoArco(
    'C',
    'Cancelación',
    'Que eliminemos tus datos.',
    'Solicítalo por correo. Borraremos tu cuenta y todo lo asociado a ella; no se puede deshacer.',
  ),
  DerechoArco(
    'O',
    'Oposición',
    'Negarte a un uso específico de tus datos.',
    'Desactiva el resumen semanal en Perfil → Notificaciones → Alertas por Correo. Los usos necesarios '
        '(generar guías, calificar exámenes) no pueden separarse del servicio: si no estás de acuerdo con ellos, solicita la cancelación de tu cuenta.',
  ),
];

const String revocacionTexto =
    'Para revocar tu consentimiento, solicita por correo la cancelación de tu cuenta. La revocación no tiene efectos retroactivos.';

const List<String> solicitudPorCorreo = [
  'Escribe a ${LegalInfo.correoPrivacidad} desde el correo de tu cuenta.',
  'Incluye tu nombre, el correo de tu cuenta, el derecho que quieres ejercer y una descripción clara de los datos. '
      'Para rectificar, indica qué dato y cuál es el correcto.',
  'Te responderemos en un máximo de 20 días hábiles y, si procede, lo haremos efectivo dentro de los 15 días hábiles siguientes. '
      'Estos plazos solo pueden ampliarse una vez por un periodo igual (art. 31 de la ley).',
];