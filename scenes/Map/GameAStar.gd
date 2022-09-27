extends AStar2D
class_name GameAStar

const Direction = Enums.Direction

var _id_map := {}
var _logger := SxLog.get_logger("GameAStar")

###########
# Lifecycle

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

################
# Public methods

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
