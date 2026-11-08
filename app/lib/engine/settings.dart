/// Tunable engine parameters (the "dials" from the prototype).
///
/// The CRT dials (curvature, vignette, …) are consumed by the fragment-shader
/// pass; `twinkle` drives the starfield. Defaults are the tuned values.
class EngineSettings {
  double curvature;
  double vignette;
  double scanlines;
  double glow;
  double bezelN;
  double bezelInset;
  double aspect;
  double twinkle;
  int theme;

  EngineSettings({
    this.curvature = 0.25,
    this.vignette = 0.40,
    this.scanlines = 0.42,
    this.glow = 0.55,
    this.bezelN = 5.0,
    this.bezelInset = 0.0,
    this.aspect = 1.78,
    this.twinkle = 3.0,
    this.theme = 0,
  });
}
