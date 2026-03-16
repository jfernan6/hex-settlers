# Hex Settlers — Claude Project Instructions

## Project Overview
A 3D Catan-inspired board game built in Godot 4.5.1. Working title: "Hex Settlers."
Eventually intended for online multiplayer (host public or play with friends).
Developer: jfernan6 (GitHub). First 3D game project — learning as we go.

## Machine Specs
- CPU: Intel i7-13800H (14 cores / 20 threads)
- RAM: 32 GB DDR5
- GPU: NVIDIA RTX A1000 6GB (dedicated) — use Vulkan renderer in Godot
- OS: Windows 11 Enterprise
- Display: 4K (3840x2400)
- Git installed at: C:\Users\jefernandez\AppData\Local\Programs\Git\

## Project Paths
- Project root: C:\Users\jefernandez\Desktop\game_dev\hex-settlers\
- GitHub remote: https://github.com/jfernan6/hex-settlers
- Engine: Godot 4.5.1 (Windows Standard 64-bit, no install — portable .exe)
- Godot binary (once downloaded): C:\Users\jefernandez\Desktop\game_dev\godot\

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
- Prefer @export variables for inspector-configurable values
- One script per scene where possible
- Hex grid uses axial coordinates (q, r) — cube coords for math, convert to axial for storage
- Use Vulkan renderer (not Compatibility) — machine supports it

## Git Workflow
- Branch: main (primary)
- Feature branches for each phase: phase/01-setup, phase/02-board, etc.
- Commit after each meaningful milestone (not every file save)
- Commit message format: `[Phase X] Short description of what was done`
- Always pull before starting a session if collaborating
- Never commit Godot's .godot/ cache folder or import files

## Development Phases
1. Setup — Install Godot, import assets, render first hex tile
2. Board — Generate 19-tile Catan board with hex grid, terrain types, number tokens
3. Pieces — Load 3D models, click-to-place settlements/cities/roads
4. Rules — Dice, resource collection, robber, trading, building costs, VP, win condition
5. Hot-seat — Local multiplayer (pass-and-play on one machine)
6. Online — Godot 4 ENet/WebSocket multiplayer, lobby, state sync

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
