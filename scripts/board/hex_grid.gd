class_name HexGrid

## Hex grid math using axial coordinates (q, r).
## Uses flat-top hexagon orientation.
## Reference: https://www.redblobgames.com/grids/hexagons/

# Size = circumradius of each hex tile (matches CylinderMesh top_radius).
# Multiply by 1.05 to leave a small visual gap between tiles.
const HEX_SIZE: float = 1.47   # 1.05 * 1.40 — bigger tiles allow better model scale
const SQRT3: float = 1.7320508

## Harbour types: -1 = generic 3:1, 0–4 = specific 2:1 matching resource IDs.
const HARBOR_GENERIC: int = -1

## 9 harbours: type, world-space XZ position of the marker, and the XZ of the
## two board-edge vertices whose settlements receive the port discount.
## Vertex y is always HexVertices.SLOT_HEIGHT (0.15) — ignored by _dist_xz checks.
const HARBORS: Array = [
	{"type": -1, "px": -5.51, "pz":  3.18, "v1x": -5.145, "v1z":  3.819, "v2x": -5.880, "v2z":  2.546},
	{"type": -1, "px": -2.21, "pz":  5.73, "v1x": -1.470, "v1z":  5.092, "v2x": -2.940, "v2z":  5.092},
	{"type":  3, "px":  3.31, "pz":  4.46, "v1x":  3.675, "v1z":  3.819, "v2x":  2.940, "v2z":  5.092},
	{"type":  4, "px":  5.51, "pz":  3.18, "v1x":  5.880, "v1z":  2.546, "v2x":  5.145, "v2z":  3.819},
	{"type": -1, "px":  5.51, "pz": -3.18, "v1x":  5.145, "v1z": -3.819, "v2x":  5.880, "v2z": -2.546},
	{"type":  0, "px":  2.21, "pz": -5.73, "v1x":  1.470, "v1z": -5.092, "v2x":  2.940, "v2z": -5.092},
	{"type": -1, "px": -3.31, "pz": -4.46, "v1x": -3.675, "v1z": -3.819, "v2x": -2.940, "v2z": -5.092},
	{"type":  1, "px": -5.51, "pz": -3.18, "v1x": -5.880, "v1z": -2.546, "v2x": -5.145, "v2z": -3.819},
	{"type":  2, "px": -5.51, "pz":  0.64, "v1x": -5.145, "v1z":  1.273, "v2x": -5.880, "v2z":  0.000},
]


## Returns the 19 axial positions that make up the standard Catan board.
## Arranged as: center (1) + ring 1 (6) + ring 2 (12) = 19
static func get_board_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.append(Vector2i(0, 0))
	for pos in _get_ring_positions(1):
		positions.append(pos)
	for pos in _get_ring_positions(2):
		positions.append(pos)

	# Validate: catch duplicates early
	var seen: Dictionary = {}
	var duplicates := 0
	for p in positions:
		var key := "%d,%d" % [p.x, p.y]
		if key in seen:
			print("[HEXGRID] ERROR: Duplicate position q=%d r=%d!" % [p.x, p.y])
			duplicates += 1
		seen[key] = true
	print("[HEXGRID] Positions: %d total, %d unique  [%s]" % [
		positions.size(), seen.size(),
		"OK" if duplicates == 0 and positions.size() == 19 else "ERROR"
	])
	return positions

## Converts axial coordinates (q, r) to a 3D world position (flat-top).
static func axial_to_world(q: int, r: int) -> Vector3:
	var x: float = HEX_SIZE * 1.5 * q
	var z: float = HEX_SIZE * SQRT3 * (r + q * 0.5)
	return Vector3(x, 0.0, z)

## Returns axial positions for all tiles in a given ring radius.
static func _get_ring_positions(radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	# Six directions to walk around the ring (flat-top axial, redblobgames order)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	# Start: move (radius) steps in direction[4] = (-1, 1) from center
	var pos := Vector2i(-radius, radius)
	for side in range(6):
		for _step in range(radius):
			results.append(pos)
			pos += directions[side]
	return results
