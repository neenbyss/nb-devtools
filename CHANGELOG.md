# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-25

### Added

- **Coords tool** — real-time player position (x/y/z/heading) and camera position
  (x/y/z/rotation/FOV) with one-click copy in `vec4`, `vector3`, Lua table, and
  raw formats.
- **Entity Placer** — spawn a ghost ped or prop at your position and reposition it
  with keyboard controls (WASD / Space / Ctrl / arrow keys / Shift for fast mode);
  confirm with Enter to get the final coordinates.
- **Free Camera** — full free-fly scripted camera using matrix-based movement;
  mouse look, WASD + Space/Ctrl for elevation, scroll wheel for FOV; exits cleanly
  with Backspace.
- **Entity Inspector** — continuous raycast from the camera crosshair showing entity
  type, model hash, Net ID, health, invincibility state, and hit-point coordinates;
  vehicle extras (plate, speed).
- **NUI panel** — dark developer panel with four tabs (Coords / Placer / Camera /
  Inspector), draggable header, copy buttons for every output, and a keyboard-active
  badge when focus is released to the game.
- **Admin gate** — server-side permission check via `nb-bridge`; `Config.AdminOnly`
  toggle; auto-granted on player load for admins.
- **Toggle command** `/nbd` with configurable `F10` keybinding
  (`RegisterKeyMapping`).
- **Ped and prop presets** — eight quick-spawn presets per type in `config.lua`,
  accessible from the Placer tab dropdown.

[Unreleased]: https://github.com/Neenbyss/nb-devtools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Neenbyss/nb-devtools/releases/tag/v1.0.0
