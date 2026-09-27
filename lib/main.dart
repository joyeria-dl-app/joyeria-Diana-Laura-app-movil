import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const JoyeriaApp());
}

class JoyeriaApp extends StatelessWidget {
  const JoyeriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joyería Diana Laura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
