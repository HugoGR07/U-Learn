import 'package:flutter/material.dart';
import 'views/home_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'U-Learn',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto', // O la fuente por defecto de Flutter
      ),
      home: const HomeView(),
    );
  }
}