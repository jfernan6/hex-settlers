class_name HexEdges

## Computes all unique edge positions for the hex board.
## A standard 19-tile Catan board has exactly 72 unique edges (road slots).
## Each edge connects two adjacent vertices and belongs to 1 or 2 tiles.

const HexGrid = preload("res://scripts/board/hex_grid.gd")

const SLOT_HEIGHT: float = 0.15  # same plane as vertex slots


## Returns all unique edges for the board.
## Each entry: { midpoint: Vector3, v1: Vector3, v2: Vector3, direction: Vector3 }
static func get_all_edges(board_positions: Array[Vector2i]) -> Array:
	var seen: Dictionary = {}
	var edges: Array = []

	for axial in board_positions:
		var center := HexGrid.axial_to_world(axial.x, axial.y)
		for i in range(6):
			var a_angle := deg_to_rad(i * 60.0)
			var b_angle := deg_to_rad(((i + 1) % 6) * 60.0)

			var ax: float = center.x + cos(a_angle) * HexGrid.HEX_SIZE
			var az: float = center.z + sin(a_angle) * HexGrid.HEX_SIZE
			var bx: float = center.x + cos(b_angle) * HexGrid.HEX_SIZE
			var bz: float = center.z + sin(b_angle) * HexGrid.HEX_SIZE

			var mx: float = (ax + bx) * 0.5
			var mz: float = (az + bz) * 0.5

			# Deduplicate by sorted vertex pair (integer-snapped)
			var ka := "%d,%d" % [roundi(ax * 1000), roundi(az * 1000)]
			var kb := "%d,%d" % [roundi(bx * 1000), roundi(bz * 1000)]
			var key := (ka + "|" + kb) if ka < kb else (kb + "|" + ka)

			if key not in seen:
				seen[key] = true
				var v1 := Vector3(ax, SLOT_HEIGHT, az)
				var v2 := Vector3(bx, SLOT_HEIGHT, bz)
				var mid := Vector3(mx, SLOT_HEIGHT, mz)
				var dir := (v2 - v1).normalized()
				edges.append({"midpoint": mid, "v1": v1, "v2": v2, "direction": dir})

	var status := "OK" if edges.size() == 72 else "ERROR — expected 72 (got %d)" % edges.size()
	print("[HEXEDGES] Unique edges: %d  [%s]" % [edges.size(), status])
	return edges
