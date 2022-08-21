extends Object
class_name TileController

const Direction = Enums.Direction
const VEC_INF := Vector2(INF, INF)

var _node_coords := {}
var _node_coords_lookup := {}
var _empty_coords := {}
var _node_status := {}
var _level_size: Vector2
var _logger := SxLog.get_logger("TileController")

func _init(level_size: Vector2) -> void:
    _level_size = level_size
    for x in range(0, _level_size.x):
        for y in range(0, _level_size.y):
            _empty_coords[Vector2(x, y)] = true

func get_node_position(node: Node2D) -> Vector2:
    return _node_coords[node]

func get_known_nodes() -> Dictionary:
    return _node_coords

func set_node_position(node: Node2D, pos: Vector2) -> void:
    remove_node_position(node)
    _node_coords[node] = pos

    if _node_coords_lookup.has(pos):
        _node_coords_lookup[pos].append(node)
    else:
        _node_coords_lookup[pos] = [node]
        _empty_coords.erase(pos)

func remove_node_position(node: Node2D) -> void:
    if _node_coords.has(node):
        var previous_pos := _node_coords[node] as Vector2
        var nodes := _node_coords_lookup[previous_pos] as Array
        nodes.erase(node)

        if len(nodes) == 0:
            _node_coords_lookup.erase(previous_pos)
            _empty_coords[previous_pos] = true
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
    var empty_coords := _empty_coords.keys()
    if empty_coords.empty():
        return VEC_INF
    return SxRand.choice_array(empty_coords)

func compute_astar() -> GameAStar:
    var astar = GameAStar.new(self)
    return astar

class GameAStar:
    extends AStar2D

    var _id_map := {}
    var _logger := SxLog.get_logger("GameAStar")

    func _init(controller: TileController) -> void:
        var next_id := 0

        for x in range(controller._level_size.x):
            for y in range(controller._level_size.y):
                var coord := Vector2(x, y)
                var weight := 1

                if controller._node_coords_lookup.has(coord):
                    for target in controller._node_coords_lookup[coord]:
                        if target is Crate:
                            weight = 10
                            break
                        if target is Player:
                            weight = 10
                            break

                add_point(next_id, coord, weight)
                _id_map[coord] = next_id
                next_id += 1

        for x0 in range(controller._level_size.x - 1):
            var x1 := x0 + 1
            for y0 in range(controller._level_size.y - 1):
                var y1 := y0 + 1
                var coords0 := Vector2(x0, y0)
                var coords1 := Vector2(x1, y0)
                var coords2 := Vector2(x0, y1)
                var valid0 := true
                var valid1 := true
                var valid2 := true

                if controller._node_coords_lookup.has(coords0):
                    for target in controller._node_coords_lookup[coords0]:
                        if target is Wall:
                            valid0 = false
                            break

                if controller._node_coords_lookup.has(coords1):
                    for target in controller._node_coords_lookup[coords1]:
                        if target is Wall:
                            valid1 = false
                            break

                if controller._node_coords_lookup.has(coords2):
                    for target in controller._node_coords_lookup[coords2]:
                        if target is Wall:
                            valid2 = false
                            break

                if valid0 && valid1:
                    connect_points(_id_map[coords0], _id_map[coords1], true)
                if valid0 && valid2:
                    connect_points(_id_map[coords0], _id_map[coords2], true)

    func get_next_direction_to_coords(source: Vector2, target: Vector2) -> int:
        var source_id := _id_map[source] as int
        var target_id := _id_map[target] as int
        var path := get_point_path(source_id, target_id)
        if len(path) > 1:
            var first := path[1]
            if first.x > source.x && first.y == source.y:
                return Direction.RIGHT
            elif first.x < source.x && first.y == source.y:
                return Direction.LEFT
            elif first.x == source.x && first.y > source.y:
                return Direction.DOWN
            elif first.x == source.x && first.y < source.y:
                return Direction.UP

        return Utils.rand_direction()
