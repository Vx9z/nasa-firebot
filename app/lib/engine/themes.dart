import 'dart:ui';

/// A phosphor theme for the CRT layer.
class EngineTheme {
  final String name;
  final Color color;

  const EngineTheme(this.name, this.color);
}

/// Built-in themes — add more entries here to extend.
const List<EngineTheme> engineThemes = [
  EngineTheme('Fallout', Color(0xFF00FF00)),
  EngineTheme('Amber', Color(0xFFFFB000)),
  EngineTheme('TRON', Color(0xFF00F0FF)),
  EngineTheme('Synthwave', Color(0xFFFF00AA)),
  EngineTheme('Red Alert', Color(0xFFFF3C3C)),
  EngineTheme('Phosphor', Color(0xFFBEDCFF)),
  EngineTheme('Green', Color(0xFF3FB950)),
  EngineTheme('Blue', Color(0xFF58A6FF)),
  EngineTheme('Purple', Color(0xFFBC8CFF)),
  EngineTheme('Orange', Color(0xFFFFA657)),
  EngineTheme('Pink', Color(0xFFFF66C4)),
];

/// Safe theme lookup by index (wraps around).
EngineTheme themeByIndex(int index) => engineThemes[index % engineThemes.length];
