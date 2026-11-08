import 'package:flutter/material.dart';

import '../controllers/curriculum_controller.dart';
import '../controllers/vault_controller.dart';
import 'engine_view.dart';
import 'terminal_commands.dart';

/// The entire app is the CRT terminal — no Material UI, just the engine.
class EngineHome extends StatefulWidget {
  const EngineHome({super.key});

  @override
  State<EngineHome> createState() => _EngineHomeState();
}

class _EngineHomeState extends State<EngineHome> {
  int _themeIndex = 0;
  late final TerminalCommands _commands = TerminalCommands(
    onThemeChanged: (i) => setState(() => _themeIndex = i),
  );

  @override
  void initState() {
    super.initState();
    CurriculumController.instance.load();
    VaultController.instance.vault.load();
  }

  @override
  Widget build(BuildContext context) {
    return EngineView(
      themeIndex: _themeIndex,
      onCommand: _commands.run,
      onThemeChanged: (i) => setState(() => _themeIndex = i),
    );
  }
}
