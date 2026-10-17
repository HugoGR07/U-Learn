import 'package:flutter/material.dart';
import 'views/home_view.dart';
import 'views/courses_view.dart';
import 'views/login_view.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  final sesionActiva = await ApiService.restoreSession();

  ApiService.onSessionExpired = () {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeView()),
      (route) => false,
    );
    nav.push(MaterialPageRoute(builder: (_) => const LoginView()));
  };

  runApp(MyApp(sesionActiva: sesionActiva));
}

class MyApp extends StatelessWidget {
  final bool sesionActiva;
  const MyApp({super.key, this.sesionActiva = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'U-Learn',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto', // O la fuente por defecto de Flutter
      ),
      home: sesionActiva ? const CoursesView() : const HomeView(),
    );
  }
}