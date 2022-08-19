extends Node2D

const Direction = Enums.Direction
const CrateScene = preload("res://scenes/Crate.tscn")
const PlayerScene = preload("res://scenes/Player.tscn")
const WallScene = preload("res://scenes/Wall.tscn")
const BombScene = preload("res://scenes/Bomb.tscn")
const BubbleScene = preload("res://scenes/Bubble.tscn")
const ExplosionFXScene = preload("res://scenes/ExplosionFX.tscn")

const TWEEN_SPEED = 0.25
const GAME_TIME_LIMIT = 120
var PLAYER_COLOR_ROULETTE = [
    Color.red.lightened(0.5),
    Color.green.lightened(0.5),
    Color.blue.lightened(0.5)
]

onready var _bg_tilemap := $Background as TileMap
onready var _md_tilemap := $Middleground as TileMap
onready var _fg_tilemap := $Foreground as TileMap
onready var _camera := $Camera as SxFXCamera
onready var _tiles := $Tiles as Node2D
onready var _bubbles := $Bubbles as Node2D
onready var _hud := $HUD as HUD
onready var _cell_size := _md_tilemap.cell_size

var _object_coords := {}
var _object_coords_lookup := {}
var _player_status := {}
var _player_bubbles := {}
var _logger := SxLog.get_logger("Game")
var _remaining_time := float(GAME_TIME_LIMIT)
var _game_running := true

func _spawn_tiles() -> void:
    var last_player_id := 1
    var tilemap := _md_tilemap
    var tilemap_rect := tilemap.get_used_rect()
    for pos in tilemap.get_used_cells():
        var tile_idx := tilemap.get_cellv(pos)
        var tile_name := tilemap.tile_set.tile_get_name(tile_idx)

        if tile_name == "player":
            _spawn_player(pos, last_player_id)
            tilemap.set_cellv(pos, -1)
            last_player_id += 1

        elif tile_name == "crate":
            _spawn_crate(pos)
            tilemap.set_cellv(pos, -1)

        elif tile_name == "wall":
            _spawn_wall(pos)
            tilemap.set_cellv(pos, -1)

        elif tile_name == "bomb":
            _spawn_bomb(pos)
            tilemap.set_cellv(pos, -1)

    _camera.set_limit_from_rect(tilemap_rect.expand(_cell_size * tilemap_rect.end))

func _get_players_center() -> Vector2:
    var players := _player_status.values()
    var player_count := len(players)
    var center := Vector2()

    if player_count == 0:
        return center

    for entry in players:
        var player := entry as Player
        center += player.position
    return center / player_count

func _spawn_player(pos: Vector2, player_index: int) -> void:
    var player: Player = PlayerScene.instance()
    player.position = _get_snapped_pos(pos)
    player.player_index = player_index
    player.player_color = SxRand.choice_array(PLAYER_COLOR_ROULETTE)
    player.connect("move", self, "_on_player_movement", [ player ])
    player.connect("spawn_bomb", self, "_on_player_spawn_bomb", [ player ])
    player.connect("exploded", self, "_on_player_dead", [ player ])
    player.connect("tree_exiting", self, "_remove_object_pos", [ player ])
    _tiles.get_node("Player").add_child(player)
    _set_object_pos(player, pos)

    var bubble: Bubble = BubbleScene.instance()
    bubble.player_index = player_index
    _bubbles.add_child(bubble)
    _player_bubbles[player_index] = bubble
    _player_status[player_index] = player

func _spawn_crate(pos: Vector2) -> void:
    var crate: Crate = CrateScene.instance()
    crate.position = _get_snapped_pos(pos)
    crate.connect("tree_exiting", self, "_remove_object_pos", [ crate ])
    _tiles.get_node("BelowPlayer").add_child(crate)
    _set_object_pos(crate, pos)

func _spawn_wall(pos: Vector2) -> void:
    var wall: Wall = WallScene.instance()
    wall.position = _get_snapped_pos(pos)
    _tiles.get_node("BelowPlayer").add_child(wall)
    _set_object_pos(wall, pos)

func _get_snapped_pos(map_pos: Vector2) -> Vector2:
    return _md_tilemap.map_to_world(map_pos) + _cell_size / 2

func _tween_to_snapped_pos(object: Node2D, map_pos: Vector2) -> void:
    var tween := get_tree().create_tween()
    var snapped_pos = _get_snapped_pos(map_pos)
    tween.tween_property(object, "position", snapped_pos, TWEEN_SPEED)
    yield(tween, "finished")

func _get_object_pos(object: Node) -> Vector2:
    return _object_coords[object.get_path()]

func _set_object_pos(object: Node, pos: Vector2) -> void:
    _remove_object_pos(object)
    _object_coords[object.get_path()] = pos

    if _object_coords_lookup.has(pos):
        _object_coords_lookup[pos].append(object)
    else:
        _object_coords_lookup[pos] = [object]

func _get_objects_at_pos(pos: Vector2) -> Array:
    if _object_coords_lookup.has(pos):
        return _object_coords_lookup[pos]
    return []

func _remove_object_pos(object: Node) -> void:
    var obj_path = object.get_path()
    if _object_coords.has(obj_path):
        var previous_pos = _object_coords[obj_path]
        var array: Array = _object_coords_lookup[previous_pos]
        array.erase(object)
        if len(array) == 0:
            _object_coords_lookup.erase(previous_pos)
        _object_coords.erase(obj_path)

func _can_move_to_pos(_object: Node, pos: Vector2) -> bool:
    var targets := _get_objects_at_pos(pos)
    return len(targets) == 0

func _on_player_movement(direction: int, player: Player) -> void:
    player.lock()

    var current_pos := _get_object_pos(player)
    var next_pos := _add_direction_to_pos(current_pos, direction)
    if _can_move_to_pos(player, next_pos):
        _set_object_pos(player, next_pos)
        yield(_tween_to_snapped_pos(player, next_pos), "completed")

    # Player can be destroyed
    if is_instance_valid(player):
        player.unlock()

func _on_player_spawn_bomb(player: Player) -> void:
    var current_pos := _get_object_pos(player)
    _spawn_bomb(current_pos)

func _on_player_dead(player: Player) -> void:
    _player_status.erase(player.player_index)
    _player_bubbles.erase(player.player_index)
    if len(_player_status) == 1:
        _hud.show_win(_player_status.keys()[0])
        _stop_game()

func _spawn_bomb(pos: Vector2) -> void:
    var targets = _get_objects_at_pos(pos)
    for target in targets:
        if target is Bomb:
            return

    var bomb: Bomb = BombScene.instance()
    bomb.power_bomb = SxRand.chance_bool(25)
    bomb.connect("explode", self, "_on_bomb_explosion", [bomb])
    bomb.position = _get_snapped_pos(pos)
    _tiles.get_node("BelowPlayer").add_child(bomb)
    _set_object_pos(bomb, pos)

func _spawn_explosion(pos: Vector2) -> bool:
    var targets = _get_objects_at_pos(pos)
    for target in targets:
        if target is Bomb:
            var bomb: Bomb = target
            _logger.info_m("_spawn_explosion", "Will trigger bomb %s" % bomb)
            bomb.trigger()
        elif target is Crate:
            var crate: Crate = target
            _logger.info_m("_spawn_explosion", "Will explode crate %s" % crate)
            crate.queue_free()
        elif target is Player:
            var player: Player = target
            _logger.info_m("_spawn_explosion", "Will explode player %s" % player)
            player.explode()
        elif target is Wall:
            return false

    var explosion: Node2D = ExplosionFXScene.instance()
    explosion.connect("tree_exiting", self, "_remove_object_pos", [explosion])
    explosion.position = _get_snapped_pos(pos)
    _tiles.get_node("AbovePlayer").add_child(explosion)
    _set_object_pos(explosion, pos)
    return true

func _on_bomb_explosion(bomb: Bomb) -> void:
    var pos = _get_object_pos(bomb)
    _remove_object_pos(bomb)
    _spawn_explosion(pos)

    if bomb.power_bomb:
        for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
            var cursor = pos
            while true:
                cursor = cursor + dir
                if !_spawn_explosion(cursor):
                    break
    else:
        _spawn_explosion(pos + Vector2(1, 0))
        _spawn_explosion(pos + Vector2(1, 1))
        _spawn_explosion(pos + Vector2(-1, 0))
        _spawn_explosion(pos + Vector2(-1, -1))
        _spawn_explosion(pos + Vector2(0, -1))
        _spawn_explosion(pos + Vector2(1, -1))
        _spawn_explosion(pos + Vector2(0, 1))
        _spawn_explosion(pos + Vector2(-1, 1))

func _add_direction_to_pos(pos: Vector2, direction: int) -> Vector2:
    match direction:
        Direction.LEFT:
            return Vector2(pos.x - 1, pos.y)
        Direction.RIGHT:
            return Vector2(pos.x + 1, pos.y)
        Direction.UP:
            return Vector2(pos.x, pos.y - 1)
        Direction.DOWN:
            return Vector2(pos.x, pos.y + 1)
    return Vector2()

func _ready() -> void:
    _spawn_tiles()

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var event_key = event as InputEventKey
        if event_key.physical_scancode == KEY_ENTER:
            get_tree().reload_current_scene()

func _stop_game() -> void:
    _game_running = false
    for player_idx in _player_status:
        var player := _player_status[player_idx] as Player
        player.set_process(false)

func _process(delta: float) -> void:
    if _game_running:
        _remaining_time -= delta
        if _remaining_time <= 0:
            _hud.update_hud(0)
            _hud.show_time_out()
            _stop_game()
        else:
            _hud.update_hud(_remaining_time)

    var vp_size := get_viewport_rect().size
    var half_vp_size := vp_size / 2
    _camera.position = _get_players_center() - half_vp_size

    # If player are out of camera screen, show in bubble
    for idx in _player_status:
        var player := _player_status[idx] as Player
        var player_coords = player.global_position
        var bubble := _player_bubbles[player.player_index] as Bubble
        var show_bubble := false
        var bubble_offset := bubble.get_size() / 1.5

        if player_coords.x > _camera.position.x + vp_size.x:
            bubble.position.x = _camera.position.x + vp_size.x - bubble_offset.x
            show_bubble = true
        elif player_coords.x < _camera.position.x:
            bubble.position.x = _camera.position.x + bubble_offset.x
            show_bubble = true
        else:
            bubble.position.x = player_coords.x

        if player_coords.y > _camera.position.y + vp_size.y:
            bubble.position.y = _camera.position.y + vp_size.y - bubble_offset.y
            show_bubble = true
        elif player_coords.y < _camera.position.y:
            bubble.position.y = _camera.position.y + bubble_offset.y
            show_bubble = true
        else:
            bubble.position.y = player_coords.y

        bubble.rotate_towards(player_coords)

        if show_bubble:
            if !bubble.visible:
                bubble.fade_in()
        else:
            if bubble.visible:
                bubble.fade_out()
