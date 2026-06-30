import 'package:flutter/material.dart';

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
      home: const Scaffold(
        backgroundColor: Color(0xFFFCF0D9),
        body: Center(
          child: Text(
            'ReadEase 🎉',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A3A),
            ),
          ),
        ),
      ),
    );
  }
}