# Hex Settlers

A 3D Catan-inspired board game built with Godot 4. Collect resources, build settlements, trade with other players, and race to 10 victory points.

## Status
Active prototype with playable board flow, AI turns, development cards, logging, and a lightweight test suite.

## Tech Stack
- **Engine:** Godot 4.6.1
- **Language:** GDScript
- **Renderer:** Forward Plus / Vulkan
- **Networking:** Godot 4 built-in ENet (planned)

## Current State
- Main menu entrypoint and playable in-engine scene transition
- 3D board generation with terrain, number tokens, robber, and build slots
- Core turn flow, AI player scaffolding, dev cards, HUD, and event logging
- Built-in unit-style GDScript test runner
- Debug screenshot and debug-play hooks for development sessions

## Planned Next Areas
- Continue tightening full rules coverage and AI behavior
- Expand piece interaction and polish scene/UI feedback
- Add local hot-seat support
- Add online multiplayer after single-machine play is stable

## Asset Credits
- 3D hex tiles and buildings: [Kenney.nl](https://kenney.nl) (CC0)
- Audio: [OpenGameArt.org](https://opengameart.org) (CC0/CC-BY)

## Running the Game
1. Install Godot 4.6.1.
2. Open Godot and import `/Users/jeremy/Code/hex-settlers/project.godot`.
3. Run the project. The startup scene is `scenes/main_menu.tscn`.

## Command Line
- Run tests: `godot --path /Users/jeremy/Code/hex-settlers -- --run-tests`
- Run a debug screenshot capture: `./run_debug.sh`
- Run directly from the repo root: `godot --path /Users/jeremy/Code/hex-settlers`

## License
MIT — see LICENSE file. Game mechanics inspired by Catan (Catan GmbH). No official Catan assets used.
