import 'package:flutter/material.dart';

import 'engine/engine_home.dart';
import 'splash.dart';
import 'theme.dart';

void main() {
  runApp(const FireSafetyApp());
}

class FireSafetyApp extends StatefulWidget {
  const FireSafetyApp({super.key});

  @override
  State<FireSafetyApp> createState() => _FireSafetyAppState();
}

class _FireSafetyAppState extends State<FireSafetyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire in Freefall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fire.material,
      home: Stack(
        fit: StackFit.expand,
        children: [
          const EngineHome(),
          if (_showSplash)
            IntroSplash(
              onFinished: () => setState(() => _showSplash = false),
            ),
        ],
      ),
    );
  }
}
