import 'package:flutter/material.dart';
import 'package:flutter_ink_eval/canvas_screen.dart';

void main() {
  runApp(const InkEvalApp());
}

class InkEvalApp extends StatelessWidget {
  const InkEvalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Ink Eval',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: const CanvasScreen(),
    );
  }
}
