# Terminal Macros & Editing Keys

Editing controls for the retro terminal (Layer 3), with status and design notes.

## Implemented

| Key | Action |
|---|---|
| (type) | Insert character |
| Backspace | Delete previous character |
| **Ctrl+Backspace** | Delete previous word |
| **Ctrl+U** | Clear the line |
| Enter | Submit command (echoed to history) |

## Planned — need a cursor position in the input model

The input is currently a plain string; cursor-based keys require tracking a
cursor index (a small refactor).

| Key | Action |
|---|---|
| ← / → | Move cursor |
| Ctrl+← / Ctrl+→ | Jump word-by-word |
| Home / End | Line start / end |
| Ctrl+A / Ctrl+E | Line start / end |
| Ctrl+W | Delete previous word (alt of Ctrl+Backspace) |
| Ctrl+K | Cut from cursor to end of line |
| ↑ / ↓ | Command history navigation |
| Ctrl+C | Interrupt / cancel line |
| Ctrl+L | Clear screen |
| Tab | Autocomplete (once a command registry exists) |

## Design notes

- **History**: keep the last N submitted commands; ↑/↓ walk through them.
- **Autocomplete**: needs a command table (e.g. `CLEAR`, `STATUS`, `HELP`, …).
- **Ctrl+C**: should cancel the current line (and later, interrupt a running
  command), not quit the app.
