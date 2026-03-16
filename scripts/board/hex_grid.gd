class_name HexGrid

## Hex grid math using axial coordinates (q, r).
## Uses flat-top hexagon orientation.
## Reference: https://www.redblobgames.com/grids/hexagons/

# Size = circumradius of each hex tile (matches CylinderMesh top_radius).
# Multiply by 1.05 to leave a small visual gap between tiles.
const HEX_SIZE: float = 1.05
const SQRT3: float = 1.7320508

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
