# Chrome District (Godot 4 scaffold)

Isometric cyberpunk city builder. Port of the browser prototype.
See `GAME_DESIGN.md` for the setting and the design roadmap.

## Run
1. Install Godot 4.3 or newer (standard build, not .NET).
2. Godot Project Manager > Import > select `project.godot`.
3. Press F5.

## Controls
Left-click: build, or demolish / clear shanties with tool 5. 1-5: choose tool. Right/middle drag or arrow keys: pan. Wheel: zoom.

## Structure
- `scripts/sim/`  Pure simulation (no nodes, no drawing). `CityState` holds data and rules; `Simulation` ticks it at a fixed rate.
  `MapGenerator` builds the starting shanty-town map; `TerrainDefs` describes the ground types.
- `scripts/view/` Isometric drawing, mouse picking, camera.
- `scripts/ui/`   HUD built in code.
- `scripts/main.gd` Wires the three together.

Rule of thumb: the view and HUD read the simulation; only `main.gd` tells the simulation to change.
