"""Layer 1 (bottom) — a static starfield with occasional gentle twinkling.

Stars sit at fixed screen positions (no movement) and each twinkles on its own
slow phase. `twinkle` controls how strongly they flicker.
"""
import math
import random

RAMP = " .·+*#"   # dim -> bright


class Starfield:
    def __init__(self, count=120, twinkle=1.0, seed=7):
        self.twinkle = twinkle
        self.rng = random.Random(seed)
        self.stars = [
            [
                self.rng.uniform(0.0, 1.0),      # x (normalized 0..1)
                self.rng.uniform(0.0, 1.0),      # y
                self.rng.uniform(0.25, 1.0),     # base brightness
                self.rng.uniform(0.0, 6.283),    # twinkle phase
                self.rng.uniform(0.08, 0.4),     # twinkle speed (slow)
            ]
            for _ in range(count)
        ]

    def draw(self, cells, t):
        W = len(cells[0]) if cells else 0
        H = len(cells)
        amp = min(1.0, self.twinkle * 0.5)
        for x, y, bright, phase, spd in self.stars:
            ix = int(x * (W - 1))
            iy = int(y * (H - 1))
            if 0 <= ix < W and 0 <= iy < H:
                blink = 1.0 - amp * (0.5 + 0.5 * math.sin(t * spd + phase))
                v = bright * blink
                idx = min(int(v * (len(RAMP) - 1)), len(RAMP) - 1)
                if idx >= 1:
                    cur = cells[iy][ix]
                    cur_idx = RAMP.index(cur) if cur in RAMP else -1
                    if idx > cur_idx:
                        cells[iy][ix] = RAMP[idx]
