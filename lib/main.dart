import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/api_client.dart';

void main() {
  runApp(
    Provider<ApiClient>(
      create: (_) => ApiClient(),
      child: const JoyeriaApp(),
    ),
  );
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
