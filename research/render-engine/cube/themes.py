"""Named phosphor themes for the CRT."""
THEMES = {
    "Fallout":    (0, 255, 0),
    "Amber":      (255, 176, 0),
    "TRON":       (0, 240, 255),
    "Synthwave":  (255, 0, 170),
    "Red Alert":  (255, 60, 60),
    "Phosphor":   (190, 220, 255),
}
THEME_NAMES = list(THEMES.keys())


def color_of(theme_index):
    """Return the RGB tuple for a theme index."""
    return THEMES[THEME_NAMES[int(theme_index) % len(THEME_NAMES)]]
