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

func _get_player_name(player_index: int, is_cpu: bool) -> String:
    if is_cpu:
        return ._get_player_name(player_index, is_cpu)
    else:
        var players := _get_server_peer().get_players()
        var player_ids := players.keys()
        var owner := player_ids[player_index - 1] as int
        return players[owner]

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

func _setup_player_input(player: Player, player_index: int, is_cpu: bool) -> void:
    if is_cpu:
        ._setup_player_input(player, player_index, is_cpu)
    else:
        var players := _get_server_peer().get_players()
        var player_ids := players.keys()
        var owner := player_ids[player_index - 1] as int
        var player_input := NetPlayerInput.new()
        player_input.player_index = player_index
        player_input.name = "PlayerInput"
        player_input.set_network_master(owner)
        player.add_child(player_input)

func _on_tile_removed(node: Node2D) -> void:
    _tile_controller.remove_node_position(node)

    # Do not spam clients with tile removal after game over (like on scene disposal)
    if !_game_ended && !_get_server_peer().is_quitting():
        _send_client_message(
            GameMessage.TileRemoved,
            {"path": _tiles.get_path_to(node)}
        )

func _send_client_message(message_type: int, payload: Dictionary):
    rpc("_on_client_message", message_type, payload)

#################
# Client code

puppet func _on_client_message(message_type: int, payload: Dictionary) -> void:
    match message_type:
        GameMessage.PlayerSpawned:
            var player: Player = PlayerScene.instance()
            player.position = _get_snapped_pos(payload["pos"])
            player.player_index = payload["player_index"]
            player.player_color = SxRand.choice_array(PLAYER_COLOR_ROULETTE)
            player.player_name = payload["player_name"]
            player.name = payload["name"]
            player.lock()

            # Dummy input
            var player_input = PlayerInput.new()
            player_input.name = "PlayerInput"
            player.add_child(player_input)
            player.set_process(false)

            _tiles.get_node("Player").add_child(player)
            _mg_tilemap.set_cellv(payload["pos"], -1)

        GameMessage.WallSpawned:
            var wall: Wall = WallScene.instance()
            wall.position = _get_snapped_pos(payload["pos"])
            wall.name = payload["name"]
            _tiles.get_node("BelowPlayer").add_child(wall)
            _mg_tilemap.set_cellv(payload["pos"], -1)

        GameMessage.CrateSpawned:
            var crate: Crate = CrateScene.instance()
            crate.position = _get_snapped_pos(payload["pos"])
            crate.name = payload["name"]
            _tiles.get_node("BelowPlayer").add_child(crate)
            _mg_tilemap.set_cellv(payload["pos"], -1)

        GameMessage.ItemSpawned:
            var item: Item = ItemScene.instance()
            item.item_type = payload["item_type"]
            item.position = _get_snapped_pos(payload["pos"])
            item.name = payload["name"]
            _tiles.get_node("BelowPlayer").add_child(item)

        GameMessage.BombSpawned:
            var bomb: Bomb = BombScene.instance()
            bomb.power_bomb = payload["is_power_bomb"]
            bomb.position = _get_snapped_pos(payload["pos"])
            bomb.name = payload["name"]
            _tiles.get_node("BelowPlayer").add_child(bomb)

        GameMessage.ExplosionSpawned:
            var explosion: Node2D = ExplosionFXScene.instance()
            explosion.position = _get_snapped_pos(payload["pos"])
            _tiles.get_node("BelowPlayer").add_child(explosion)

        GameMessage.PlayerMoved:
            var player := _tiles.get_node("Player/%s" % payload["player_name"]) as Player
            player._direction = payload["direction"]
            player._move_state = Player.MoveState.MOVING
            player._update_animation_state()
            yield(_tween_to_snapped_pos(player, payload["next_pos"]), "completed")
            player._move_state = Player.MoveState.IDLE
            player._update_animation_state()

        GameMessage.BombMoved:
            var bomb := _tiles.get_node(payload["path"]) as Bomb
            yield(_tween_to_snapped_pos(bomb, payload["next_pos"]), "completed")

        GameMessage.PlayerExploded:
            var player := _tiles.get_node(payload["player_path"]) as Player
            player.explode()

        GameMessage.TileRemoved:
            var t = _tiles.get_node_or_null(payload["path"])
            if t != null:
                t.queue_free()

        GameMessage.ItemPicked:
            var item := _tiles.get_node("BelowPlayer/%s" % payload["item_name"]) as Item
            item.pickup()

    _handle_ui_message(message_type, payload)
