extends "res://screens/Game.gd"
class_name NetGame

onready var _lobby := get_parent()

func _get_server_peer() -> SxServerPeer:
    return get_parent()._server_peer

func _master_setup_level() -> void:
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
    rpc("_setup_level", _bg_tilemap.get("tile_data"), _mg_tilemap.get("tile_data"))
    _continue_setup()

func _setup_game():
    var barrier = _create_barrier("BSetup")

    if SxNetwork.is_network_server(get_tree()):
        yield(barrier.await_peers(), "completed")
        _master_setup_level()

func _create_barrier(name: String) -> SxSyncBarrier:
    var barrier = SxSyncBarrier.new(name)
    if SxNetwork.is_network_server(get_tree()):
        barrier.set_server_peer(_get_server_peer())
    add_child(barrier)
    return barrier

puppet func _setup_level(bg_data, mg_data):
    var LevelScene := load("res://levels/MapData.tscn")
    var level := LevelScene.instance() as Node2D
    self.add_child_below_node(_camera, level)

    _bg_tilemap = level.get_node("Background") as TileMap
    _mg_tilemap = level.get_node("Middleground") as TileMap
    _fg_tilemap = level.get_node("Foreground") as TileMap

    _bg_tilemap.set("tile_data", bg_data)
    _mg_tilemap.set("tile_data", mg_data)

    _cell_size = _mg_tilemap.cell_size
    _map_rect = _mg_tilemap.get_used_rect()

    _tile_controller = TileController.new(_map_rect.size)
    _prepare_camera()

puppet func _client_start_game() -> void:
    yield(_hud.show_ready(), "completed")
    _game_running = true

puppet func _client_game_setup() -> void:
    _create_barrier("BContinue")

func _continue_setup() -> void:
    _tile_controller = TileController.new(_map_rect.size)
    _spawn_tiles()
    _prepare_camera()

    _item_timer.wait_time = item_spawn_frequency
    _item_timer.connect("timeout", self, "_spawn_item_at_empty_position")
    _game_running = false

    # Wait for all clients
    var barrier = _create_barrier("BContinue")
    rpc("_client_game_setup")
    yield(barrier.await_peers(), "completed")

    rpc("_client_start_game")
    yield(_hud.show_ready(), "completed")
    _start_game()

func _on_player_hud_setup(scores: Dictionary) -> void:
    ._on_player_hud_setup(scores)
    rpc("_client_on_player_hud_setup", scores)

func _on_player_score_update(player_index: int, score: int) -> void:
    rpc("_client_on_player_score_update", player_index, score)

func _setup_player_input(player: Player, player_index: int) -> void:
    var players := _get_server_peer().get_players()
    var player_ids := players.keys()

    if player_index - 1 >= _human_players:
        ._setup_player_input(player, player_index)
    else:
        var owner := player_ids[player_index - 1] as int
        var player_input := NetPlayerInput.new()
        player_input.player_index = player_index
        player_input.name = "PlayerInput"
        player_input.set_network_master(owner)
        player.add_child(player_input)

func _on_player_spawned(pos: Vector2, player_index: int, name: String) -> void:
    rpc("_on_client_player_spawned", pos, player_index, name)
func _on_wall_spawned(pos: Vector2, name: String) -> void:
    rpc("_on_client_wall_spawned", pos, name)
func _on_crate_spawned(pos: Vector2, name: String) -> void:
    rpc("_on_client_crate_spawned", pos, name)
func _on_item_spawned(pos: Vector2, item_type: int, name: String) -> void:
    rpc("_on_client_item_spawned", pos, item_type, name)
func _on_bomb_spawned(pos: Vector2, is_power_bomb: bool, name: String) -> void:
    rpc("_on_client_bomb_spawned", pos, is_power_bomb, name)
func _on_explosion_spawned(pos: Vector2) -> void:
    rpc("_on_client_explosion_spawned", pos)
func _on_player_moved(player: Player, next_pos: Vector2) -> void:
    rpc("_on_client_player_moved", player.name, player._direction, next_pos)
func _on_bomb_moved(bomb: Bomb, next_pos: Vector2) -> void:
    rpc("_on_client_bomb_moved", bomb.name, next_pos)

func _on_tile_removed(node: Node2D) -> void:
    ._on_tile_removed(node)

    # Do not spam clients with tile removal after game over (like on scene disposal)
    if !_game_ended:
        rpc("_on_client_tile_removed", _tiles.get_path_to(node))

func _on_player_explode(player: Player) -> void:
    rpc("_on_client_player_explode", _tiles.get_path_to(player))

func _endgame(winner: int) -> void:
    ._endgame(winner)
    rpc("_on_client_endgame", winner)

func _on_item_pick(player_index: int, item: Item) -> void:
    rpc("_on_client_item_pick", player_index, item.name, item.item_type)

puppet func _on_client_endgame(winner: int):
    ._endgame(winner)

puppet func _on_client_player_spawned(pos: Vector2, player_index: int, name: String) -> void:
    var player: Player = PlayerScene.instance()
    player.position = _get_snapped_pos(pos)
    player.player_index = player_index
    player.player_color = SxRand.choice_array(PLAYER_COLOR_ROULETTE)
    player.player_name = name
    player.name = name
    player.lock()

    # Dummy input
    var player_input = PlayerInput.new()
    player_input.name = "PlayerInput"
    player.add_child(player_input)
    player.set_process(false)

    _tiles.get_node("Player").add_child(player)
    _mg_tilemap.set_cellv(pos, -1)

puppet func _on_client_wall_spawned(pos: Vector2, name: String) -> void:
    var wall: Wall = WallScene.instance()
    wall.position = _get_snapped_pos(pos)
    wall.name = name
    _tiles.get_node("BelowPlayer").add_child(wall)
    _mg_tilemap.set_cellv(pos, -1)

puppet func _on_client_crate_spawned(pos: Vector2, name: String) -> void:
    var crate: Crate = CrateScene.instance()
    crate.position = _get_snapped_pos(pos)
    crate.name = name
    _tiles.get_node("BelowPlayer").add_child(crate)
    _mg_tilemap.set_cellv(pos, -1)

puppet func _on_client_item_spawned(pos: Vector2, item_type: int, name: String) -> void:
    var item: Item = ItemScene.instance()
    item.item_type = item_type
    item.position = _get_snapped_pos(pos)
    item.name = name
    _tiles.get_node("BelowPlayer").add_child(item)

puppet func _on_client_bomb_spawned(pos: Vector2, is_power_bomb: bool, name: String) -> void:
    var bomb: Bomb = BombScene.instance()
    bomb.power_bomb = is_power_bomb
    bomb.position = _get_snapped_pos(pos)
    bomb.name = name
    _tiles.get_node("BelowPlayer").add_child(bomb)

puppet func _on_client_explosion_spawned(pos: Vector2) -> void:
    var explosion: Node2D = ExplosionFXScene.instance()
    explosion.position = _get_snapped_pos(pos)
    _tiles.get_node("BelowPlayer").add_child(explosion)

puppet func _on_client_player_moved(player_name: String, direction: int, next_pos: Vector2) -> void:
    var player := _tiles.get_node("Player/%s" % player_name) as Player
    player._direction = direction
    player._move_state = Player.MoveState.MOVING
    player._update_animation_state()
    yield(_tween_to_snapped_pos(player, next_pos), "completed")
    player._move_state = Player.MoveState.IDLE
    player._update_animation_state()

puppet func _on_client_bomb_moved(bomb_name: String, next_pos: Vector2) -> void:
    var bomb := _tiles.get_node("BelowPlayer/%s" % bomb_name) as Bomb
    yield(_tween_to_snapped_pos(bomb, next_pos), "completed")

puppet func _on_client_player_explode(player_path: String) -> void:
    var player := _tiles.get_node(player_path) as Player
    player.explode()

puppet func _on_client_tile_removed(path: String) -> void:
    var t = _tiles.get_node_or_null(path)
    if t != null:
        t.queue_free()

remote func _client_on_player_score_update(player_index: int, score: int) -> void:
    _hud.update_player_score(player_index, score)

puppet func _client_on_player_hud_setup(scores: Dictionary) -> void:
    _hud.setup_player_hud(scores)

puppet func _on_client_item_pick(player_index: int, item_name: String, item_type: int) -> void:
    var item := _tiles.get_node("BelowPlayer/%s" % item_name) as Item
    item.pickup()
    _hud.add_player_item(player_index, item_type)