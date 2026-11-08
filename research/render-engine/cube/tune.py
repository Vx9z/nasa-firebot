"""Live tuner — layered scene (starfield + terminal) with a dial per effect.

Usage:
    python tune.py            open the interactive window (animation + sliders)
    python tune.py --once     render a few seconds and save scene_preview.png
    python tune.py --smoke    construct the UI and exit (verifies widgets build)

Layer 1 (starfield) gets the full CRT pass; layer 3 (terminal) gets only a light
pass so its text stays legible. Drag dials to tune both the scene and the CRT.
"""
import sys
import time
import tkinter as tk

from PIL import ImageTk

from main import CELL_W, CELL_H
from scene import Scene
from themes import THEME_NAMES

# Live preview grid (cells); the image is LW*CELL_W x LH*CELL_H pixels.
LW, LH = 80, 40

DEFAULTS = {
    "curvature": 0.25,
    "vignette": 0.30,
    "scanlines": 0.42,
    "glow": 0.55,
    "bezel_n": 5.00,
    "bezel_inset": 0.00,
    "aspect": 1.78,   # 16:9
    "star_twinkle": 3.0,
    "theme": 0,
}

# (label, key, min, max, step)
DIALS = [
    ("curvature",    "curvature",    0.00, 0.25, 0.005),
    ("vignette",     "vignette",     0.00, 0.70, 0.010),
    ("scanlines",    "scanlines",    0.00, 0.85, 0.010),
    ("glow",         "glow",         0.00, 0.95, 0.010),
    ("bezel n",      "bezel_n",      2.00, 5.00, 0.100),
    ("bezel inset",  "bezel_inset",  0.00, 0.12, 0.005),
    ("screen aspect","aspect",       0.50, 2.00, 0.025),
    ("star twinkle", "star_twinkle", 0.00, 4.00, 0.050),
]


class Tuner:
    def __init__(self, root):
        self.root = root
        self.d = dict(DEFAULTS)
        self.vars = {}
        self.t = 0.0
        self.last = time.perf_counter()
        self.scene = Scene(LW, LH)

        # Left: live preview canvas.
        self.canvas = tk.Canvas(root, width=LW * CELL_W, height=LH * CELL_H,
                                bg="black", cursor="none")
        self.canvas.pack(side="left", padx=8, pady=8)
        self.photo = None
        self.image_id = self.canvas.create_image(0, 0, anchor="nw")
        self.canvas.bind("<Motion>", self._on_motion)
        self.canvas.bind("<Leave>", lambda e: self.scene.sonar.hide())

        # Right: the dials.
        panel = tk.Frame(root)
        panel.pack(side="left", fill="y", padx=8, pady=8)
        tk.Label(panel, text="DIALS", font=("Consolas", 12, "bold")).pack(anchor="w")

        # Theme selector (dial) — discrete, so it gets its own control.
        trow = tk.Frame(panel)
        trow.pack(fill="x", pady=3)
        tk.Label(trow, text="theme", width=13, anchor="w").pack(side="left")
        self.theme_var = tk.IntVar(value=int(self.d["theme"]))
        self.theme_var.trace_add("write", lambda *a: self._set_theme())
        tk.Scale(
            trow, from_=0, to=len(THEME_NAMES) - 1, resolution=1,
            variable=self.theme_var, orient="horizontal", length=190,
            showvalue=False,
        ).pack(side="left")
        self.theme_name = tk.Label(trow, text=THEME_NAMES[int(self.d["theme"])], width=10, anchor="w")
        self.theme_name.pack(side="left")

        for label, key, lo, hi, res in DIALS:
            row = tk.Frame(panel)
            row.pack(fill="x", pady=3)
            tk.Label(row, text=f"{label:13s}", width=13, anchor="w").pack(side="left")
            var = tk.DoubleVar(value=self.d[key])
            self.vars[key] = var
            var.trace_add("write", lambda *a, k=key, v=var: self._set(k, v))
            tk.Scale(
                row, from_=lo, to=hi, resolution=res, variable=var,
                orient="horizontal", length=190, showvalue=True, digits=3,
            ).pack(side="left")
        tk.Button(panel, text="Reset dials", command=self.reset).pack(pady=6)

        root.bind_all("<Key>", self._on_key)   # make the terminal typeable
        self._draw(0.0)

    def _set(self, key, var):
        self.d[key] = var.get()
        self.scene.invalidate()

    def _set_theme(self):
        self.d["theme"] = self.theme_var.get()
        self.theme_name.config(text=THEME_NAMES[self.d["theme"]])
        self.scene.invalidate()

    def reset(self):
        for key, val in DEFAULTS.items():
            self.d[key] = val
            if key in self.vars:
                self.vars[key].set(val)
        self.theme_var.set(int(DEFAULTS["theme"]))

    def _draw(self, dt):
        img = self.scene.render(self.t, dt, self.d)
        self.photo = ImageTk.PhotoImage(img)
        self.canvas.itemconfig(self.image_id, image=self.photo)

    def _on_motion(self, event):
        self.scene.sonar.move(event.x, event.y)

    def _on_key(self, event):
        term = self.scene.terminal
        ctrl = bool(event.state & 0x4)
        if ctrl and event.keysym == "BackSpace":
            term.delete_word()
        elif ctrl and event.keysym.lower() == "u":
            term.clear_line()
        elif event.keysym == "BackSpace":
            term.backspace()
        elif event.keysym == "Return":
            term.enter()
        elif event.char and len(event.char) == 1 and event.char.isprintable():
            term.key(event.char)

    def loop(self):
        now = time.perf_counter()
        dt = now - self.last
        self.last = now
        self.t += dt
        self._draw(dt)
        self.root.after(16, self.loop)


if __name__ == "__main__":
    if "--once" in sys.argv:
        sc = Scene(LW, LH)
        d = dict(DEFAULTS)
        img = None
        for i in range(120):            # ~2 s of typing
            img = sc.render(i * 0.016, 0.016, d)
        img.save("scene_preview.png")
        print(f"once: saved scene_preview.png ({img.size[0]}x{img.size[1]})")
        sys.exit(0)

    root = tk.Tk()
    root.title("CRT Tuner — layered scene + dials")
    if "--smoke" in sys.argv:
        root.withdraw()
    app = Tuner(root)
    if "--smoke" in sys.argv:
        root.update_idletasks()
        print("smoke: UI constructed OK")
        root.destroy()
        sys.exit(0)
    app.loop()
    root.mainloop()

