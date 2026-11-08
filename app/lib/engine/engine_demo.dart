import 'package:flutter/material.dart';

import 'engine_view.dart';
import 'terminal_commands.dart';
import 'themes.dart';

/// Throwaway screen to eyeball the engine port — the terminal is fully wired to
/// the app (notes / lessons / chat / theme) via [TerminalCommands].
class EngineDemoPage extends StatefulWidget {
  const EngineDemoPage({super.key});

  @override
  State<EngineDemoPage> createState() => _EngineDemoPageState();
}

class _EngineDemoPageState extends State<EngineDemoPage> {
  int _themeIndex = 0;
  late final TerminalCommands _commands = TerminalCommands(
    onThemeChanged: (i) => setState(() => _themeIndex = i),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Engine Demo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          DropdownButton<int>(
            value: _themeIndex,
            dropdownColor: Colors.black,
            items: [
              for (var i = 0; i < engineThemes.length; i++)
                DropdownMenuItem(value: i, child: Text(engineThemes[i].name)),
            ],
            onChanged: (v) => setState(() => _themeIndex = v ?? 0),
          ),
        ],
      ),
      body: EngineView(themeIndex: _themeIndex, onCommand: _commands.run),
    );
  }
}
