extends Node2D

const Direction = Enums.Direction
const GameMode = Enums.GameMode
const CrateScene = preload("res://scenes/Crate.tscn")
const PlayerScene = preload("res://scenes/Player/Player.tscn")
const WallScene = preload("res://scenes/Wall.tscn")
const BombScene = preload("res://scenes/Bomb.tscn")
const ItemScene = preload("res://scenes/Item.tscn")
const BubbleScene = preload("res://scenes/Bubble.tscn")
const ExplosionFXScene = preload("res://scenes/ExplosionFX.tscn")

enum GameMessage {
    BombExploded,
    BombMoved,
    BombSpawned,
    CrateSpawned,
    Endgame
    ExplosionSpawned,
    ItemPicked,
    ItemSpawned,
    PlayerExploded,
    PlayerHudSetup,
    PlayerMoved,
    PlayerScoreUpdated,
    PlayerSpawned,
    TileRemoved,
    WallSpawned,
}

class PlayerData:
    const DEFAULT_BOMB_LIMIT := 3

    var player: Player
    var player_index: int
    var player_name := ""
    var bomb_limit := DEFAULT_BOMB_LIMIT
    var current_active_bombs := 0
    var active_items := {}

    func _init(player_: Player) -> void:
        player = player_
        player_index = player_.player_index
        player_name = player_.player_name

    func incr_active_bombs() -> void:
        current_active_bombs += 1

    func decr_active_bombs() -> void:
        current_active_bombs -= 1

    func can_place_bomb() -> bool:
        return current_active_bombs < bomb_limit

    func set_item_active(item_type: int) -> void:
        match item_type:
            Item.ItemType.Bomb:
                bomb_limit += 2
            _:
                active_items[item_type] = true

    func set_item_inactive(item_type: int) -> void:
        active_items.erase(item_type)

export var item_spawn_frequency := 10.0
export var game_time_limit := 120

signal game_over()

const TWEEN_SPEED := 0.25

var PLAYER_COLOR_ROULETTE = [
    Color.red.lightened(0.5),
    Color.green.lightened(0.5),
    Color.blue.lightened(0.5),
    Color.greenyellow.lightened(0.5)
]

onready var _camera := $Camera as SxFXCamera
onready var _tiles := $Tiles as Node2D
onready var _hud := $HUD as HUD
onready var _item_timer := $ItemTimer as Timer

var _bg_tilemap: TileMap
var _mg_tilemap: TileMap
var _fg_tilemap: TileMap
var _cell_size: Vector2
var _map_rect: Rect2
var _max_players: int
var _human_players: int

var _player_data := {}
var _logger := SxLog.get_logger("Game")
var _remaining_time := float(game_time_limit)
var _game_running := false
var _game_ended := false
var _tile_controller: TileController

var _last_free_id := 0

###########
# Lifecycle

func _ready() -> void:
    _max_players = GameData.game_max_players
    _human_players = GameData.game_human_players

    _setup_game()

func _setup_game() -> void:
    match GameData.map_name:
        "Map01":
            _load_level("Map01")
        "Map02":
            _load_level("Map02")
        _:
            _load_random_level()

    _tile_controller = TileController.new(_map_rect.size)
    _spawn_tiles()
    _prepare_camera()

    _item_timer.wait_time = item_spawn_frequency
    _item_timer.connect("timeout", self, "_spawn_item_at_empty_position")

    yield(_hud.show_ready(), "completed")

    _start_game()

func _process(delta: float) -> void:
    if _game_running:
        _remaining_time -= delta
        if _remaining_time <= 0:
            _hud.update_hud(0)
            _hud.show_time_out()
            _stop_game()
        else:
            _hud.update_hud(_remaining_time)

###############
# Level loading

func _load_level(name: String) -> void:
    var LevelScene := load("res://levels/%s.tscn" % name)
    var level := LevelScene.instance() as Node2D
    self.add_child_below_node(_camera, level)

    _bg_tilemap = level.get_node("Background") as TileMap
    _mg_tilemap = level.get_node("Middleground") as TileMap
    _fg_tilemap = level.get_node("Foreground") as TileMap
    _cell_size = _mg_tilemap.cell_size
    _map_rect = _mg_tilemap.get_used_rect()

func _load_random_level() -> void:
    var LevelScene := load("res://levels/MapData.tscn")
    var level := LevelScene.instance() as Node2D
    self.add_child_below_node(_camera, level)

    _bg_tilemap = level.get_node("Background") as TileMap
    _mg_tilemap = level.get_node("Middleground") as TileMap
    _fg_tilemap = level.get_node("Foreground") as TileMap

    var randomizer := MapRandomizer.new(_bg_tilemap, _mg_tilemap)
    randomizer.generate(_max_players, Vector2(30, 20))

    _cell_size = _mg_tilemap.cell_size
    _map_rect = _mg_tilemap.get_used_rect()

###############
# Spawn methods

func _spawn_tiles() -> void:
    var player_index := 1

    var tilemap := _mg_tilemap
    for pos in tilemap.get_used_cells():
        var tile_idx := tilemap.get_cellv(pos)
        var tile_name := tilemap.tile_set.tile_get_name(tile_idx)

        if tile_name == "player":
            _spawn_player(pos, player_index)
            tilemap.set_cellv(pos, -1)
            player_index = wrapi(player_index + 1, 1, _max_players + 1)

        elif tile_name == "crate":
            _spawn_crate(pos)
            tilemap.set_cellv(pos, -1)

        elif tile_name == "wall":
            _spawn_wall(pos)
            tilemap.set_cellv(pos, -1)

    _setup_player_hud()

func _setup_player_hud():
    var scores := {}
    var names := {}
    for idx in _player_data:
        scores[idx] = GameData.last_scores.get(idx, 0)
        names[idx] = _player_data[idx].player_name
    GameData.update_scores(scores)
    _send_client_message(
        GameMessage.PlayerHudSetup,
        {"scores": scores, "names": names}
    )

func _play_fx(name: String) -> void:
    var audio_fx := GameLoadCache.instantiate_scene("TempAudioFX") as TempAudioFX
    audio_fx.min_pitch_offset = 0.5
    audio_fx.max_pitch_offset = 1.5
    audio_fx.stream = GameLoadCache.load_resource(name)
    add_child(audio_fx)

func _spawn_player(pos: Vector2, player_index: int) -> void:
    var player: Player = PlayerScene.instance()
    player.position = _get_snapped_pos(pos)
    player.player_index = player_index
    player.player_color = SxRand.choice_array(PLAYER_COLOR_ROULETTE)
    player.name = "Player%d" % _get_free_item_id()

    player.connect("move", self, "_on_player_movement", [ player ])
    player.connect("spawn_bomb", self, "_on_player_spawn_bomb", [ player ])
    player.connect("push_bomb", self, "_on_player_push_bomb", [ player ])
    player.connect("exploded", self, "_on_player_dead", [ player ])
    player.connect("tree_exiting", self, "_on_tile_removed", [ player ])
    player.lock()

    # Input
    var is_cpu = player_index - 1 >= _human_players
    _setup_player_input(player, player_index, is_cpu)

    var player_name = _get_player_name(player_index, is_cpu)
    player.player_name = player_name

    _tiles.get_node("Player").add_child(player)
    _tile_controller.set_node_position(player, pos)

    var pdata := PlayerData.new(player)
    _player_data[player.player_index] = pdata

    var owner = player.get_node("PlayerInput").get_network_master()
    _send_client_message(
        GameMessage.PlayerSpawned,
        {"name": player.name, "pos": pos, "player_index": player_index, "owner": owner, "player_name": pdata.player_name}
    )

func _get_player_name(player_index: int, is_cpu: bool) -> String:
    var player_name := "P%d" % player_index
    if player_index == 1:
        player_name = GameData.player_username
    elif is_cpu:
        player_name = "CPU%d" % player_index
    return player_name

func _setup_player_input(player: Player, player_index: int, is_cpu: bool) -> void:
    if is_cpu:
        var player_input = AIPlayerInput.new(_tile_controller)
        player_input.name = "PlayerInput"
        player.add_child(player_input)
        player.player_name = "CPU%d" % player_index

func _add_player_score(player_index: int, delta: int) -> void:
    var score := GameData.add_player_score(player_index, delta)
    _send_client_message(
        GameMessage.PlayerScoreUpdated,
        {"player_index": player_index, "score": score}
    )

func _spawn_crate(pos: Vector2) -> void:
    var crate: Crate = CrateScene.instance()
    crate.position = _get_snapped_pos(pos)
    crate.connect("tree_exiting", self, "_on_tile_removed", [ crate ])
    crate.name = "Crate%d" % _get_free_item_id()
    _tiles.get_node("BelowPlayer").add_child(crate)
    _tile_controller.set_node_position(crate, pos)
    _send_client_message(
        GameMessage.CrateSpawned,
        {"name": crate.name, "pos": pos}
    )

func _spawn_wall(pos: Vector2) -> void:
    var wall: Wall = WallScene.instance()
    wall.position = _get_snapped_pos(pos)
    wall.name = "Wall%d" % _get_free_item_id()
    _tiles.get_node("BelowPlayer").add_child(wall)
    _tile_controller.set_node_position(wall, pos)
    _send_client_message(
        GameMessage.WallSpawned,
        {"name": wall.name, "pos": pos}
    )

func _spawn_item_at_empty_position() -> void:
    var pos := _tile_controller.get_random_empty_position()
    if pos == TileController.VEC_INF:
        # Edge case: no more empty positions
        return

    var item_type := Item.random_item_type()
    var item: Item = ItemScene.instance()
    item.item_type = item_type
    item.position = _get_snapped_pos(pos)
    item.name = "Item%d" % _get_free_item_id()
    item.connect("tree_exiting", self, "_on_tile_removed", [ item ])
    _tiles.get_node("BelowPlayer").add_child(item)
    _tile_controller.set_node_position(item, pos)
    _send_client_message(
        GameMessage.ItemSpawned,
        {"item_type": item.item_type, "name": item.name, "pos": pos}
    )

func _spawn_bomb(pos: Vector2, is_power_bomb: bool, spawner: Player = null) -> void:
    var targets = _tile_controller.get_nodes_at_position(pos)
    for target in targets:
        if target is Bomb:
            return

    var bomb: Bomb = BombScene.instance()
    bomb.spawner = spawner
    bomb.power_bomb = is_power_bomb
    bomb.connect("explode", self, "_on_bomb_explosion", [bomb])
    bomb.position = _get_snapped_pos(pos)
    bomb.name = "Bomb%d" % _get_free_item_id()
    _tiles.get_node("BelowPlayer").add_child(bomb)
    _tile_controller.set_node_position(bomb, pos)
    _send_client_message(
        GameMessage.BombSpawned,
        {"is_power_bomb": is_power_bomb, "name": bomb.name, "pos": pos}
    )

    if spawner:
        var pdata := _player_data[spawner.player_index] as PlayerData
        pdata.incr_active_bombs()

func _on_tile_removed(node: Node2D) -> void:
    _tile_controller.remove_node_position(node)
    _send_client_message(
        GameMessage.TileRemoved,
        {"path": _tiles.get_path_to(node)}
    )

func _spawn_explosion(bomb_origin: Bomb, pos: Vector2) -> bool:
    var targets := _tile_controller.get_nodes_at_position(pos)
    for target in targets:
        if target is Bomb:
            var bomb: Bomb = target
            bomb.trigger()
        elif target is Crate:
            target.queue_free()
        elif target is Player:
            var player: Player = target
            if !player.is_alive():
                continue

            _explode_player(player)

            # Handle score
            var spawner := bomb_origin.spawner
            if spawner && is_instance_valid(spawner):
                # Special case: autodestruction, -1!
                if spawner == player:
                    _add_player_score(spawner.player_index, -1)
                else:
                    _add_player_score(spawner.player_index, 1)

        elif target is Item:
            target.queue_free()
        elif target is Wall:
            return false

    var explosion: Node2D = ExplosionFXScene.instance()
    explosion.connect("tree_exiting", self, "_on_tile_removed", [explosion])
    explosion.connect("tree_exiting", self, "_detect_endgame")
    explosion.position = _get_snapped_pos(pos)
    explosion.name = "Explosion%d" % _get_free_item_id()
    explosion.spawner = bomb_origin.spawner
    _tiles.get_node("BelowPlayer").add_child(explosion)
    _tile_controller.set_node_position(explosion, pos)
    _send_client_message(
        GameMessage.ExplosionSpawned,
        {"pos": pos}
    )
    return true

#########
# Events

func _on_player_movement(direction: int, player: Player) -> void:
    if !_game_running:
        return

    player.lock()
    var current_pos := _tile_controller.get_node_position(player)
    var next_pos := _add_direction_to_pos(current_pos, direction)
    if _can_move_to_position(player, next_pos):
        var targets := _tile_controller.get_nodes_at_position(next_pos)
        for target in targets:
            if target is Item:
                var pdata := _player_data[player.player_index] as PlayerData
                var item := target as Item
                item.pickup()
                pdata.set_item_active(item.item_type)
                _send_client_message(
                    GameMessage.ItemPicked,
                    {"player_index": player.player_index, "item_name": item.name, "item_type": item.item_type}
                )

            elif target is ExplosionFX:
                _explode_player(player)

                # Handle score
                _add_player_score(player.player_index, -1)
                var spawner := target.spawner as Player
                if spawner && is_instance_valid(spawner):
                    # Special case: autodestruction, -2!
                    if spawner == player:
                        _add_player_score(spawner.player_index, -1)
                    else:
                        _add_player_score(spawner.player_index, 1)

                return

        _tile_controller.set_node_position(player, next_pos)
        _send_client_message(
            GameMessage.PlayerMoved,
            {"player_name": player.name, "direction": player._direction, "next_pos": next_pos}
        )
        yield(_tween_to_snapped_pos(player, next_pos), "completed")

    # Player can be destroyed
    if is_instance_valid(player):
        player.unlock()

func _on_player_spawn_bomb(player: Player) -> void:
    if !_game_running:
        return

    if player.player_index in _player_data:
        var pdata := _player_data[player.player_index] as PlayerData
        if pdata.can_place_bomb():
            var current_pos := _tile_controller.get_node_position(player)
            _spawn_bomb(current_pos, _get_player_item_status(player, Item.ItemType.PowerBomb), player)

func _on_player_push_bomb(direction: int, player: Player) -> void:
    if !_game_running:
        return

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
                _send_client_message(
                    GameMessage.BombMoved,
                    {"path": _tiles.get_path_to(bomb), "next_pos": next_bomb_pos}
                )
                yield(_tween_to_snapped_pos(bomb, next_bomb_pos), "completed")
            _tile_controller.set_node_locked(bomb, false)

func _on_player_dead(player: Player) -> void:
    _player_data.erase(player.player_index)

func _explode_player(player: Player) -> void:
    player.explode()
    _send_client_message(
        GameMessage.PlayerExploded,
        {"player_path": _tiles.get_path_to(player)}
    )

func _on_bomb_explosion(bomb: Bomb) -> void:
    var pos = _tile_controller.get_node_position(bomb)
    _tile_controller.remove_node_position(bomb)
    _on_tile_removed(bomb)
    _spawn_explosion(bomb, pos)

    if bomb.spawner && is_instance_valid(bomb.spawner) && _player_data.has(bomb.spawner.player_index):
        var pdata := _player_data[bomb.spawner.player_index] as PlayerData
        pdata.decr_active_bombs()

    if bomb.power_bomb:
        for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
            var cursor = pos
            while true:
                cursor = cursor + dir
                if !_spawn_explosion(bomb, cursor):
                    break
    else:
        _spawn_explosion(bomb, pos + Vector2(1, 0))
        _spawn_explosion(bomb, pos + Vector2(-1, 0))
        _spawn_explosion(bomb, pos + Vector2(0, -1))
        _spawn_explosion(bomb, pos + Vector2(0, 1))

    _send_client_message(
        GameMessage.BombExploded,
        {}
    )

#########
# Helpers

func _detect_endgame() -> void:
    # Check if everyone is alive?
    if _game_running:
        var remaining = _get_remaining_player_indices()
        if len(remaining) == 1:
            _endgame(remaining.keys()[0])
        elif len(remaining) == 0:
            _endgame(-1)

func _endgame(winner: int):
    var winner_name = ""
    if winner != -1:
        _add_player_score(winner, 3)
        winner_name = _player_data[winner].player_name
    _stop_game()

    _send_client_message(
        GameMessage.Endgame,
        {"winner_index": winner, "winner_name": winner_name}
    )

func _get_snapped_pos(map_pos: Vector2) -> Vector2:
    return _mg_tilemap.map_to_world(map_pos) + _cell_size / 2

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

func _get_player_item_status(player: Player, item_type: int) -> bool:
    var pdata := _player_data[player.player_index] as PlayerData
    if item_type in pdata.active_items:
        return pdata.active_items[item_type]
    return false

func _get_remaining_player_indices() -> Dictionary:
    var alive := {}
    for idx in _player_data:
        alive[idx] = true
    return alive

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

func _stop_game() -> void:
    if !_game_running:
        return

    _game_running = false
    _item_timer.stop()

    for idx in _player_data:
        var pdata := _player_data[idx] as PlayerData
        pdata.player.lock()

    var nodes := _tile_controller.get_known_nodes()
    for node in nodes:
        if node is Bomb:
            var bomb := node as Bomb
            bomb.freeze()

    _game_ended = true
    emit_signal("game_over")

func _start_game() -> void:
    for idx in _player_data:
        var pdata := _player_data[idx] as PlayerData
        pdata.player.unlock()

    _game_running = true
    _item_timer.start()

func _prepare_camera() -> void:
    var offset := 6 * Vector2.ONE * _cell_size
    var vp_size := get_viewport_rect().size
    var map_size := _map_rect.size * _cell_size + offset

    var ratio_vec := map_size / vp_size
    var max_ratio_comp := max(ratio_vec.x, ratio_vec.y)
    var clamped_ratio := max(max_ratio_comp, 1)
    var map_size_ratio := map_size / clamped_ratio
    ratio_vec = Vector2(clamped_ratio, clamped_ratio)

    _camera.zoom = ratio_vec
    _camera.position = (-(vp_size - map_size_ratio) / 2) * _camera.zoom - offset / 2

func _get_free_item_id() -> int:
    _last_free_id = wrapi(_last_free_id + 1, 0, 100_000)
    return _last_free_id

func _send_client_message(message_type: int, payload: Dictionary) -> void:
    _handle_ui_message(message_type, payload)

func _handle_ui_message(message_type: int, payload: Dictionary) -> void:
    match message_type:
        GameMessage.PlayerScoreUpdated:
            _hud.update_player_score(payload["player_index"], payload["score"])

        GameMessage.PlayerHudSetup:
            _hud.setup_player_hud(payload["scores"], payload["names"])

        GameMessage.BombExploded:
            _play_fx("FXBoom")

        GameMessage.BombSpawned:
            _play_fx("FXClick")

        GameMessage.ItemPicked:
            _hud.add_player_item(payload["player_index"], payload["item_type"])
            _play_fx("FXPowerup")

        GameMessage.PlayerExploded:
            _play_fx("FXDied")

        GameMessage.BombMoved:
            _play_fx("FXPush")

        GameMessage.Endgame:
            if payload["winner_index"] != -1:
                _hud.show_win(payload["winner_name"])
            else:
                _hud.show_draw()
            _stop_game()
