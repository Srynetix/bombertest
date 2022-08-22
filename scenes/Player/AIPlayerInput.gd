# AI-controlled player input.
# Use a simple three-parts logic:
#   - Chase the first player (with AStar)
#   - Avoid bombs
#   - Spawn bombs if possible
extends "res://scenes/Player/PlayerInput.gd"
class_name AIPlayerInput

const Direction = Enums.Direction

var _tile_controller: TileController
var _player: Player
var _previous_direction = null
var _other_players: Dictionary = {}
var _bomb_positions: Dictionary = {}

###########
# Lifecycle

func _init(tile_controller: TileController) -> void:
    _tile_controller = tile_controller

func _ready() -> void:
    _player = get_parent() as Player
    _update_other_players_position()

func _process(_delta: float) -> void:
    _reset()
    _update_other_players_position()

    if len(_other_players) == 0:
        return

    var next_dir = _target_player()
    next_dir = _avoid_bombs(next_dir)
    _try_to_bomb(next_dir)

    if next_dir == -1:
        # Do not move
        pass
    else:
        keys[_direction_to_movement(next_dir)] = true

#########
# Helpers

func _update_other_players_position():
    _other_players.clear()
    _bomb_positions.clear()

    var nodes := _tile_controller.get_known_nodes()
    for node in nodes:
        if node is Player && node != _player:
            _other_players[node] = nodes[node]
        elif node is Bomb || node is ExplosionFX:
            _bomb_positions[node] = nodes[node]

func _target_player() -> int:
    var first_player = _other_players.keys()[0]
    var cur_pos := _tile_controller.get_node_position(_player)
    var astar := GameAStar.new(_tile_controller)
    var next_dir := astar.get_next_direction_to_coords(cur_pos, _other_players[first_player])
    return next_dir

func _avoid_bombs(next_dir: int) -> int:
    var cur_pos := _tile_controller.get_node_position(_player)
    var next_pos := Utils.add_direction_to_pos(cur_pos, next_dir)
    if !_is_near_bombs(next_pos):
        return next_dir

    for d in Utils.ALL_DIRECTIONS:
        if d != next_dir:
            var next_pos_l = Utils.add_direction_to_pos(cur_pos, d)
            var targets = _tile_controller.get_nodes_at_position(next_pos_l)
            var skip := false
            for target in targets:
                if target is Wall || target is Player || target is Crate:
                    skip = true
                    break
            if skip:
                continue

            if !_is_near_bombs(next_pos_l):
                return d

    if !_is_near_bombs(cur_pos):
        # Stay here
        return -1

    # Well...
    return Utils.rand_direction()

func _is_near_bombs(pos: Vector2) -> bool:
    for bomb in _bomb_positions:
        var coord := _bomb_positions[bomb] as Vector2
        if pos == coord:
            return true
        for x in Utils.ALL_DIRECTIONS:
            if Utils.add_direction_to_pos(coord, x) == pos:
                return true
    return false

func _try_to_bomb(next_dir: int) -> void:
    var cur_pos := _tile_controller.get_node_position(_player)
    var next_pos = Utils.add_direction_to_pos(cur_pos, next_dir)
    var targets = _tile_controller.get_nodes_at_position(next_pos)
    var will_bomb := false
    for target in targets:
        if target is Crate || target is Player:
            will_bomb = true

    if will_bomb:
        keys["bomb"] = true

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
