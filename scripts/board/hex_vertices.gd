class_name HexVertices

## Computes all unique vertex positions for the hex board.

const HexGrid = preload("res://scripts/board/hex_grid.gd")
## A standard 19-tile Catan board has exactly 54 unique vertices.
## Vertices are the corners where up to 3 tiles meet — where settlements go.

# Vertices sit just above the tile surface (tile height = 0.25, top = 0.125)
const SLOT_HEIGHT: float = 0.15

## Returns all unique vertex world positions for the board.
static func get_all_positions(board_positions: Array[Vector2i]) -> Array[Vector3]:
	var hex_size: float = HexGrid.HEX_SIZE
	print("[HEXVERTICES] Using HEX_SIZE = %.4f  SLOT_HEIGHT = %.4f" % [hex_size, SLOT_HEIGHT])

	var seen: Dictionary = {}
	var vertices: Array[Vector3] = []

	for axial in board_positions:
		var center := HexGrid.axial_to_world(axial.x, axial.y)
		for i in range(6):
			var angle := deg_to_rad(i * 60.0)
			var vx := center.x + cos(angle) * hex_size
			var vz := center.z + sin(angle) * hex_size
			# Use integer snap at 3dp — avoids float rounding mismatches at shared corners
			var key := "%d,%d" % [roundi(vx * 1000.0), roundi(vz * 1000.0)]
			if key not in seen:
				seen[key] = true
				vertices.append(Vector3(vx, SLOT_HEIGHT, vz))

	var status := "OK" if vertices.size() == 54 else "ERROR — expected 54 (got %d)" % vertices.size()
	print("[HEXVERTICES] Unique vertices: %d  [%s]" % [vertices.size(), status])
	return vertices
