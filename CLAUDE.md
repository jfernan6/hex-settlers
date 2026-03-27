# Hex Settlers — AI Project Notes

## Project Overview
A 3D Catan-inspired board game built in Godot 4.6.1. Working title: "Hex Settlers."
Eventually intended for online multiplayer after the single-machine gameplay loop is stable.
Developer: jfernan6 (GitHub). First 3D game project — learning as we go.

## Current Local Baseline
- Project root: `/Users/jeremy/Code/hex-settlers`
- GitHub remote: `https://github.com/jfernan6/hex-settlers`
- Engine: Godot 4.6.1
- Primary language: GDScript
- Renderer: Forward Plus / Vulkan
- Useful command: `godot --path /Users/jeremy/Code/hex-settlers -- --run-tests`

## Folder Structure
```
hex-settlers/
├── assets/
│   ├── models/       # 3D hex tiles, buildings, roads (from Kenney.nl)
│   ├── textures/     # Materials and terrain textures
│   └── audio/        # SFX and music (from OpenGameArt.org)
├── scenes/
│   ├── board/        # HexBoard.tscn, HexTile.tscn
│   ├── pieces/       # Settlement.tscn, City.tscn, Road.tscn
│   └── ui/           # HUD, menus, resource display
├── scripts/
│   ├── board/        # Hex grid logic, coordinate system, tile management
│   ├── game/         # Game state, rules, turn management, dice
│   ├── player/       # Player data, resources, actions
│   └── network/      # Multiplayer (Phase 5+)
├── CLAUDE.md
├── README.md
└── .gitignore
```

## Current Implemented Areas
- Main menu in `scenes/main_menu.tscn`
- Play scene in `scenes/main.tscn`
- Board generation and hex math under `scripts/board/`
- Turn flow, AI, dev cards, and debug hooks under `scripts/game/`
- HUD and menu scripts under `scripts/ui/`
- Lightweight test runner under `scripts/tests/`
- Debug output rooted in `debug/`

## Asset Sources
- Primary: kenney.nl/assets — Hexagon Pack, Hexagon Buildings, Board Game Pack (all CC0)
- Supplemental 3D models: sketchfab.com (free models, check license per download)
- Audio: opengameart.org (CC0/CC-BY)
- DO NOT use any official Catan artwork or assets (copyright)

## Engine Conventions (Godot 4 GDScript)
- Use GDScript (not C#) for all game logic
- snake_case for variables, functions, file names
- PascalCase for class names and scene names
- Use signals for decoupled communication between nodes
- Prefer typed `@export` variables for inspector-configurable values
- One script per scene where possible
- Hex grid uses axial coordinates (q, r) — cube coords for math, convert to axial for storage
- Keep debug output under `debug/` so scripts and `.gitignore` stay aligned

## Git Workflow
- Primary branch: `main`
- Use focused feature/chore branches for substantial work
- Commit after each meaningful milestone (not every file save)
- Commit message format can be descriptive, but should make the gameplay or tooling change obvious
- Always pull before starting a session if collaborating
- Never commit Godot's .godot/ cache folder or import files

## Development Phases
1. Stabilize current prototype, tests, and debug workflows
2. Tighten rules and AI behavior
3. Improve piece interaction and gameplay UX
4. Add hot-seat support
5. Add online multiplayer

## Key Godot 4 APIs to Know
- GridMap or manual MeshInstance3D for hex tile placement
- Area3D + CollisionShape3D for click detection on tiles/vertices
- MultiplayerSpawner + MultiplayerSynchronizer for networking (Phase 6)
- HTTPRequest node if needed for any backend calls
- SceneTree.change_scene_to_file() for scene transitions

## Trademark Note
- "Catan" is trademarked by Catan GmbH — do NOT use it in any public-facing name
- Game mechanics (hex board, resources, trading, VP) are not protected — free to implement
- All assets are original (Kenney.nl CC0) — no Catan artwork used

## Historical Note
- Earlier work was done on a Windows machine with portable Godot builds. Those paths are no longer canonical and should not be reintroduced into repo docs or scripts.
