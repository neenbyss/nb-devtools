# nb-devtools

Developer utility for FiveM — eliminate trial-and-error when positioning NPCs, props, and cameras. Get exact coordinates, headings, and entity data from an in-game panel without restarting or editing files.

> Requires [`nb-bridge`](https://github.com/neenbyss/nb-bridge) · Admin-only by default · FiveM OneSync

---

## Tools

### Coords
Real-time player position and camera data. Copy in any format you need.

| Output | Example |
|--------|---------|
| `vec4` | `vec4(120.45, -800.12, 30.12, 180.57)` |
| `vector3` | `vector3(120.45, -800.12, 30.12)` |
| Lua table | `{ x = 120.45, y = -800.12, z = 30.12, w = 180.57 }` |
| Raw | `120.45, -800.12, 30.12, 180.57` |

Camera position, rotation (RX/RY/RZ), and FOV are shown separately.

---

### Placer
Spawn a ghost ped or prop and position it with keyboard controls. No more guessing coordinates — move until it looks right, press Enter, and copy.

**Controls (active while placing):**

| Key | Action |
|-----|--------|
| `W / S` | Move forward / back |
| `A / D` | Move left / right |
| `Space / Ctrl` | Move up / down |
| `← →` | Rotate heading |
| `Shift` | 5× speed |
| `Enter` | Confirm — copy coordinates |
| `Backspace` | Cancel |

The step size is adjustable from the panel (`−` / `+` buttons: 0.001 → 1.0 m).

---

### Free Camera
Full free-fly scripted camera. Movement uses the camera's own matrix axes — correct at any pitch angle.

| Key | Action |
|-----|--------|
| `W / A / S / D` | Move |
| `Space / Ctrl` | Up / Down |
| `Shift` | Fast mode |
| Mouse | Look |
| Scroll | FOV (10° – 100°) |
| `Backspace` | Exit |

Position, rotation, and FOV update live in the panel while the camera is active.

---

### Inspector
Aim at any entity — the panel updates automatically every 300 ms.

Shows: entity type, model hash, Net ID, health, invincibility flag, world coordinates, and heading. Vehicles also show plate and speed.

The crosshair hit-point coordinates are always shown regardless of whether an entity was hit — useful for placing targets on surfaces.

---

## Installation

1. Copy the `nb-devtools` folder into your resources directory.
2. Add to `server.cfg` **after** `nb-bridge`:
   ```
   ensure nb-bridge
   ensure nb-devtools
   ```
3. No SQL required.

---

## Dependencies

| Resource | Required |
|----------|----------|
| [`nb-bridge`](https://github.com/neenbyss/nb-bridge) | ✅ |
| [`ox_lib`](https://github.com/overextended/ox_lib) | ✅ |

---

## Configuration

```lua
-- config.lua

Config.Command   = 'nbd'      -- toggle command
Config.AdminOnly = true       -- false = all players

Config.Placer = {
    Step     = 0.05,   -- default movement step (m)
    FastStep = 0.25,   -- Shift multiplier
    RotStep  = 5.0,    -- degrees per arrow press
    Alpha    = 150,    -- ghost entity opacity (0–255)
}

Config.Camera = {
    Speed      = 0.15,
    FastSpeed  = 0.8,
    FovDefault = 50.0,
    MouseSpeed = 5.0,
}
```

Ped and prop presets are defined in the `Config.PedPresets` and `Config.PropPresets` tables — add or remove entries freely.

---

## Usage

| Action | How |
|--------|-----|
| Toggle panel | `/nbd` or `F10` (rebindable in GTA V settings) |
| Switch tool | Click a tab in the panel |
| Copy a value | Click the output box or use the copy buttons |
| Keyboard mode | Panel stays visible but unfocused; click anywhere on it to regain focus |

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).

---

## License

MIT — [Neenbyss Studios](https://github.com/neenbyss)
