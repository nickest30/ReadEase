import 'package:flutter/material.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/shared/role_selection_screen.dart';

void main() {
  runApp(const ReadEaseApp());
}

class ReadEaseApp extends StatelessWidget {
  const ReadEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2BAFA0),
        ),
        useMaterial3: true,
        fontFamily: 'Nunito',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
      },
    );
  }
}