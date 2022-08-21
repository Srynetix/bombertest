extends "res://scenes/PlayerInput.gd"
class_name AIPlayerInput

const Direction = Enums.Direction

var _tile_controller: TileController
var _player: Player
var _previous_direction = null

func _init(tile_controller: TileController) -> void:
    _tile_controller = tile_controller

func _ready() -> void:
    _player = get_parent() as Player

func _process(_delta: float) -> void:
    _reset()

    var cur_pos := _tile_controller.get_node_position(_player)
    var available_directions := []
    var can_go_to_previous_direction := false

    for d in [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]:
        var target_pos := Utils.add_direction_to_pos(cur_pos, d)
        var targets := _tile_controller.get_nodes_at_position(target_pos)
        var is_blocked := false
        for target in targets:
            if target is Wall || target is Player:
                is_blocked = true
                break
        if !is_blocked:
            if d == _previous_direction:
                can_go_to_previous_direction = true
            else:
                available_directions.append(d)

    # Choose a valid direction
    if len(available_directions) > 0:
        var dir = SxRand.choice_array(available_directions)
        keys[_direction_to_movement(dir)] = true
        _previous_direction = dir
    elif can_go_to_previous_direction:
        keys[_direction_to_movement(_previous_direction)] = true

func _direction_to_movement(direction: int) -> String:
    match direction:
        Direction.LEFT:
            return "move_left"
        Direction.RIGHT:
            return "move_right"
        Direction.UP:
            return "move_up"
        Direction.DOWN:
            return "move_down"
    return ""
