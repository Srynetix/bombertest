extends Node2D

const Direction = Enums.Direction
const CrateScene = preload("res://scenes/Crate.tscn")
const PlayerScene = preload("res://scenes/Player.tscn")
const WallScene = preload("res://scenes/Wall.tscn")
const BombScene = preload("res://scenes/Bomb.tscn")
const ItemScene = preload("res://scenes/Item.tscn")
const BubbleScene = preload("res://scenes/Bubble.tscn")
const ExplosionFXScene = preload("res://scenes/ExplosionFX.tscn")

const ITEM_SPAWN_FREQUENCY = 15
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
onready var _hud := $HUD as HUD
onready var _item_timer := $ItemTimer as Timer
onready var _cell_size := _md_tilemap.cell_size
onready var _map_rect := _md_tilemap.get_used_rect()

var _player_status := {}
var _player_items := {}
var _logger := SxLog.get_logger("Game")
var _remaining_time := float(GAME_TIME_LIMIT)
var _game_running := true
var _tile_controller: TileController

func _ready() -> void:
    _tile_controller = TileController.new(_map_rect.size)
    _spawn_tiles()

    _item_timer.wait_time = ITEM_SPAWN_FREQUENCY
    _item_timer.connect("timeout", self, "_spawn_item_at_empty_position")
    _item_timer.start()

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
            _spawn_bomb(pos, false)
            tilemap.set_cellv(pos, -1)

    _camera.set_limit_from_rect(tilemap_rect.expand(_cell_size * tilemap_rect.end))

func _get_players_rect() -> Rect2:
    var players := _player_status.values()
    var player_count := len(players)

    if player_count == 0:
        return Rect2()

    var rect := Rect2(players[0].position, Vector2.ZERO)
    for idx in range(1, player_count):
        var player := players[idx] as Player
        rect = rect.expand(player.position)
    return rect

func _spawn_player(pos: Vector2, player_index: int) -> void:
    var player: Player = PlayerScene.instance()
    player.position = _get_snapped_pos(pos)
    player.player_index = player_index
    player.player_color = SxRand.choice_array(PLAYER_COLOR_ROULETTE)
    player.connect("move", self, "_on_player_movement", [ player ])
    player.connect("spawn_bomb", self, "_on_player_spawn_bomb", [ player ])
    player.connect("push_bomb", self, "_on_player_push_bomb", [ player ])
    player.connect("exploded", self, "_on_player_dead", [ player ])
    player.connect("tree_exiting", _tile_controller, "remove_node_position", [ player ])
    _tiles.get_node("Player").add_child(player)
    _tile_controller.set_node_position(player, pos)

    _player_status[player_index] = player
    _player_items[player_index] = {}

func _spawn_crate(pos: Vector2) -> void:
    var crate: Crate = CrateScene.instance()
    crate.position = _get_snapped_pos(pos)
    crate.connect("tree_exiting", _tile_controller, "remove_node_position", [ crate ])
    _tiles.get_node("BelowPlayer").add_child(crate)
    _tile_controller.set_node_position(crate, pos)

func _spawn_wall(pos: Vector2) -> void:
    var wall: Wall = WallScene.instance()
    wall.position = _get_snapped_pos(pos)
    _tiles.get_node("BelowPlayer").add_child(wall)
    _tile_controller.set_node_position(wall, pos)

func _spawn_item_at_empty_position() -> void:
    var pos := _tile_controller.get_random_empty_position()
    if pos == TileController.VEC_INF:
        # Edge case: no more empty positions
        return

    var item_type := Item.random_item_type()
    var item: Item = ItemScene.instance()
    item.item_type = item_type
    item.position = _get_snapped_pos(pos)
    item.connect("tree_exiting", _tile_controller, "remove_node_position", [ item ])
    _tiles.get_node("BelowPlayer").add_child(item)
    _tile_controller.set_node_position(item, pos)

func _get_snapped_pos(map_pos: Vector2) -> Vector2:
    return _md_tilemap.map_to_world(map_pos) + _cell_size / 2

func _tween_to_snapped_pos(object: Node2D, map_pos: Vector2) -> void:
    var tween := get_tree().create_tween()
    var snapped_pos = _get_snapped_pos(map_pos)
    tween.tween_property(object, "position", snapped_pos, TWEEN_SPEED)
    yield(tween, "finished")

func _can_move_to_position(source: Node2D, pos: Vector2) -> bool:
    var targets := _tile_controller.get_nodes_at_position(pos)
    var can_move := true
    for target in targets:
        if source is Player && (target is Item || target is ExplosionFX):
            continue
        else:
            can_move = false
            break
    return can_move

func _on_player_movement(direction: int, player: Player) -> void:
    player.lock()

    var current_pos := _tile_controller.get_node_position(player)
    var next_pos := _add_direction_to_pos(current_pos, direction)
    if _can_move_to_position(player, next_pos):
        var targets := _tile_controller.get_nodes_at_position(next_pos)
        for target in targets:
            if target is Item:
                var item := target as Item
                item.pickup()
                _player_items[player.player_index][item.item_type] = true

            elif target is ExplosionFX:
                player.explode()
                return

        _tile_controller.set_node_position(player, next_pos)
        yield(_tween_to_snapped_pos(player, next_pos), "completed")

    # Player can be destroyed
    if is_instance_valid(player):
        player.unlock()

func _on_player_spawn_bomb(player: Player) -> void:
    var current_pos := _tile_controller.get_node_position(player)
    _spawn_bomb(current_pos, _get_player_item_status(player, Item.ItemType.PowerBomb))

func _get_player_item_status(player: Player, item_type: int) -> bool:
    if item_type in _player_items[player.player_index]:
        return _player_items[player.player_index][item_type]
    return false

func _on_player_push_bomb(direction: int, player: Player) -> void:
    # Make sure the player can push
    if !_get_player_item_status(player, Item.ItemType.Push):
        return

    var current_pos := _tile_controller.get_node_position(player)
    var next_pos := _add_direction_to_pos(current_pos, direction)

    # Detect bomb
    var bomb: Bomb = null
    for target in _tile_controller.get_nodes_at_position(next_pos):
        if target is Bomb:
            bomb = target as Bomb
            break

    if bomb != null:
        if !_tile_controller.get_node_locked(bomb):
            _tile_controller.set_node_locked(bomb, true)
            var next_bomb_pos := _add_direction_to_pos(next_pos, direction)
            if _can_move_to_position(bomb, next_bomb_pos):
                _tile_controller.set_node_position(bomb, next_bomb_pos)
                yield(_tween_to_snapped_pos(bomb, next_bomb_pos), "completed")
            _tile_controller.set_node_locked(bomb, false)

func _on_player_dead(player: Player) -> void:
    _player_status.erase(player.player_index)
    if len(_player_status) == 1:
        _hud.show_win(_player_status.keys()[0])
        _stop_game()

func _spawn_bomb(pos: Vector2, is_power_bomb: bool) -> void:
    var targets = _tile_controller.get_nodes_at_position(pos)
    for target in targets:
        if target is Bomb:
            return

    var bomb: Bomb = BombScene.instance()
    bomb.power_bomb = is_power_bomb
    bomb.connect("explode", self, "_on_bomb_explosion", [bomb])
    bomb.position = _get_snapped_pos(pos)
    _tiles.get_node("BelowPlayer").add_child(bomb)
    _tile_controller.set_node_position(bomb, pos)

func _spawn_explosion(pos: Vector2) -> bool:
    var targets := _tile_controller.get_nodes_at_position(pos)
    for target in targets:
        if target is Bomb:
            var bomb: Bomb = target
            bomb.trigger()
        elif target is Crate:
            target.queue_free()
        elif target is Player:
            var player: Player = target
            player.explode()
        elif target is Item:
            target.queue_free()
        elif target is Wall:
            return false

    var explosion: Node2D = ExplosionFXScene.instance()
    explosion.connect("tree_exiting", _tile_controller, "remove_node_position", [explosion])
    explosion.position = _get_snapped_pos(pos)
    _tiles.get_node("AbovePlayer").add_child(explosion)
    _tile_controller.set_node_position(explosion, pos)
    return true

func _on_bomb_explosion(bomb: Bomb) -> void:
    var pos = _tile_controller.get_node_position(bomb)
    _tile_controller.remove_node_position(bomb)
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
        _spawn_explosion(pos + Vector2(-1, 0))
        _spawn_explosion(pos + Vector2(0, -1))
        _spawn_explosion(pos + Vector2(0, 1))

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

    _update_camera()

func _update_camera() -> void:
    var vp_size := get_viewport_rect().size
    var half_vp_size := vp_size / 2
    var players_rect = _get_players_rect()
    var players_center = players_rect.get_center()
    var players_rect_size = players_rect.size + Vector2(64, 64) * 4

    var ratio_vec = (players_rect_size / vp_size)
    var max_ratio_comp = max(ratio_vec.x, ratio_vec.y)
    var clamped_ratio = max(max_ratio_comp, 1)
    ratio_vec = Vector2(clamped_ratio, clamped_ratio)
    _camera.position = players_center - half_vp_size
    _camera.zoom = lerp(_camera.zoom, Vector2(ratio_vec), 0.025)
