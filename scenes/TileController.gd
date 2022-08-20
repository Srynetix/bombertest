extends Object
class_name TileController

var _node_coords := {}
var _node_coords_lookup := {}
var _node_status := {}
var _level_size: Vector2
var _logger := SxLog.get_logger("TileController")

func _init(level_size: Vector2) -> void:
    _level_size = level_size

func get_node_position(node: Node2D) -> Vector2:
    return _node_coords[node]

func set_node_position(node: Node2D, pos: Vector2) -> void:
    remove_node_position(node)
    _node_coords[node] = pos

    if _node_coords_lookup.has(pos):
        _node_coords_lookup[pos].append(node)
    else:
        _node_coords_lookup[pos] = [node]

func remove_node_position(node: Node2D) -> void:
    if _node_coords.has(node):
        var previous_pos := _node_coords[node] as Vector2
        var nodes := _node_coords_lookup[previous_pos] as Array
        nodes.erase(node)

        if len(nodes) == 0:
            _node_coords_lookup.erase(previous_pos)
        _node_coords.erase(node)

func get_nodes_at_position(pos: Vector2) -> Array:
    if _node_coords_lookup.has(pos):
        return _node_coords_lookup[pos]
    return []

func set_node_locked(node: Node2D, status: bool) -> void:
    if _node_status.has(node):
        _node_status[node]["locked"] = status
    else:
        _node_status[node] = {"locked": status}

func get_node_locked(node: Node2D) -> bool:
    if _node_status.has(node):
        if "locked" in _node_status[node]:
            return _node_status[node]["locked"]
    return false

func get_random_empty_position() -> Vector2:
    # FIXME: Stupid algorithm, to improve
    while true:
        var x := SxRand.range_i(0, int(_level_size.x))
        var y := SxRand.range_i(0, int(_level_size.y))
        var vec := Vector2(x, y)
        if !_node_coords_lookup.has(vec):
            return vec
    return Vector2()