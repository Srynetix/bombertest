extends Control

const DEFAULT_SERVER_PORT = 12341
const DEFAULT_MAX_PLAYERS = 4

onready var _menu := $MarginContainer/VBoxContainer/Menu as VBoxContainer
onready var _join_menu := $MarginContainer/VBoxContainer/Join as VBoxContainer
onready var _host_menu := $MarginContainer/VBoxContainer/Host as VBoxContainer
onready var _server_menu := $MarginContainer/VBoxContainer/Server as VBoxContainer
onready var _client_menu := $MarginContainer/VBoxContainer/Client as VBoxContainer

var _client_server_ip := "127.0.0.1:12341"
var _server_port := 12341
var _max_players := 4
var _server_peer: SxServerPeer
var _client_peer: SxClientPeer
var _ls_peer: SxListenServerPeer
var _game: NetGame

class LobbyStub:
    extends Control

    var _server_peer: SxServerPeer

func _ready() -> void:
    _setup_menu()
    _setup_join_menu()
    _setup_host_menu()
    _setup_server_menu()

    _hide_sub_menus()
    _setup_from_cmdline()

func _setup_from_cmdline() -> void:
    if GameData.autostart_server:
        _server_port = GameData.autostart_server_port
        _max_players = GameData.game_max_players
        _menu.hide()
        _start_server()

    elif GameData.autostart_client:
        _client_server_ip = GameData.autostart_client_server_ip
        _menu.hide()
        _join_server()

func _setup_menu() -> void:
    var join_btn := _menu.get_node("Join") as Button
    var host_btn := _menu.get_node("Host") as Button
    var back_btn := _menu.get_node("Back") as Button

    join_btn.connect("pressed", self, "_show_join_menu")
    host_btn.connect("pressed", self, "_show_host_menu")
    back_btn.connect("pressed", self, "_go_back_title")

    if OS.get_name() == "HTML5":
        # You can't create a WebSocket server on Web platform
        host_btn.hide()

func _setup_join_menu() -> void:
    var join_btn := _join_menu.get_node("Join") as Button
    var back_btn := _join_menu.get_node("Back") as Button
    var ip_field := _join_menu.get_node("IP/LineEdit") as LineEdit

    join_btn.connect("pressed", self, "_join_server")
    back_btn.connect("pressed", self, "_go_back_menu")
    ip_field.connect("text_changed", self, "_update_client_server_ip")
    ip_field.text = _client_server_ip

func _setup_server_menu() -> void:
    var start_btn := _server_menu.get_node("Start") as Button
    start_btn.disabled = true
    start_btn.connect("pressed", self, "_server_start_game")

func _setup_host_menu() -> void:
    var start_btn := _host_menu.get_node("Start") as Button
    var back_btn := _host_menu.get_node("Back") as Button
    var port_field := _host_menu.get_node("Port/LineEdit") as LineEdit
    var max_players_field := _host_menu.get_node("MaxPlayers/LineEdit") as LineEdit

    start_btn.connect("pressed", self, "_start_server")
    back_btn.connect("pressed", self, "_go_back_menu")
    port_field.connect("text_changed", self, "_update_server_port")
    max_players_field.connect("text_changed", self, "_update_max_players")

    port_field.text = str(DEFAULT_SERVER_PORT)
    max_players_field.text = str(DEFAULT_MAX_PLAYERS)

func _update_server_port(value: String) -> void:
    if int(value) == 0:
        _server_port = DEFAULT_SERVER_PORT
    else:
        _server_port = int(value)

func _update_max_players(value: String) -> void:
    if int(value) == 0:
        _max_players = DEFAULT_MAX_PLAYERS
    else:
        _max_players = int(value)

func _update_client_server_ip(value: String) -> void:
    _client_server_ip = value

func _show_join_menu() -> void:
    _menu.hide()
    _join_menu.show()

func _show_host_menu() -> void:
    _menu.hide()
    _host_menu.show()

func _join_server() -> void:
    var join_btn := _join_menu.get_node("Join") as Button
    var ip_field := _join_menu.get_node("IP/LineEdit") as LineEdit
    join_btn.disabled = true
    ip_field.editable = false

    var spl := _client_server_ip.split(":", true, 1)
    var address := spl[0] as String
    var port := int(spl[1] as String)

    _client_peer = SxClientPeer.new()
    _client_peer.use_websockets = GameData.use_websockets
    _client_peer.server_address = address
    _client_peer.server_port = port
    _client_peer.connect("connected_to_server", self, "_on_client_connected", [ false ])
    _client_peer.connect("connection_failed", self, "_on_connection_failed", [ false ])
    _client_peer.connect("server_disconnected", self, "_on_server_disconnected")
    _client_peer.connect("players_updated", self, "_client_update_players_display")
    add_child(_client_peer)

func _join_listen_server() -> void:
    var spl := _client_server_ip.split(":", true, 1)
    var address := spl[0] as String
    var port := int(spl[1] as String)

    _client_peer = SxClientPeer.new()
    _client_peer.use_websockets = GameData.use_websockets
    _client_peer.server_address = address
    _client_peer.server_port = port
    _client_peer.connect("connected_to_server", self, "_on_client_connected", [ true ])
    _client_peer.connect("connection_failed", self, "_on_connection_failed", [ true ])
    add_child(_client_peer)

func _start_server() -> void:
    _ls_peer = SxListenServerPeer.new()
    _ls_peer.use_websockets = GameData.use_websockets
    _ls_peer.server_port = _server_port
    _ls_peer.max_players = _max_players
    add_child(_ls_peer)

    # Placeholder for current scene
    var scene = LobbyStub.new()
    scene.name = name
    _ls_peer.get_server_root().add_child(scene)

    _server_peer = _ls_peer.get_server()
    scene._server_peer = _server_peer

    _server_peer.connect("players_updated", self, "_on_server_players_updated")

    _host_menu.hide()
    _server_menu.show()

    _client_server_ip = "127.0.0.1:%d" % _server_port
    _join_listen_server()

func _go_back_menu() -> void:
    _hide_sub_menus()
    _menu.show()

func _hide_sub_menus() -> void:
    _join_menu.hide()
    _host_menu.hide()
    _server_menu.hide()
    _client_menu.hide()

func _go_back_title() -> void:
    GameSceneTransitioner.fade_to_scene_path("res://screens/Title.tscn")

#####
# NET

func _on_client_connected(is_listen_server: bool) -> void:
    if !is_listen_server:
        _join_menu.hide()
        _client_menu.show()
    _client_peer._get_server().update_player_username(GameData.player_username)

func _on_connection_failed(is_listen_server: bool) -> void:
    if !is_listen_server:
        var join_btn := _join_menu.get_node("Join") as Button
        var ip_field := _join_menu.get_node("IP/LineEdit") as LineEdit
        join_btn.disabled = false
        ip_field.editable = true

func _on_server_players_updated(players: Dictionary) -> void:
    _server_update_players_display(players)
    _update_start_button(players)

func _update_start_button(players: Dictionary) -> void:
    var start_btn := _server_menu.get_node("Start") as Button
    if len(players) > 0:
        start_btn.disabled = false
    else:
        start_btn.disabled = true

func _client_update_players_display(players: Dictionary) -> void:
    var players_lbl := $MarginContainer/VBoxContainer/Client/Players as Label
    var player_names := []
    for k in players:
        var v := players[k] as String
        player_names.append("%s #%d" % [v, k])
    players_lbl.text = "\n".join(player_names)

func _server_update_players_display(players: Dictionary) -> void:
    var players_lbl := $MarginContainer/VBoxContainer/Server/Players as Label
    var player_names := []
    for k in players:
        var v := players[k] as String
        player_names.append("%s (ID #%d)" % [v, k])
    players_lbl.text = "\n".join(player_names)

func _server_start_game() -> void:
    # Hide lobby
    $MarginContainer.visible = false

    # Define vars
    GameData.game_human_players = len(_server_peer.get_players())

    var this_node := get_path()
    _game = _server_peer.spawn_synchronized_scene(this_node, "res://screens/networking/NetGame.tscn") as NetGame
    _game.connect("game_over", self, "_restart_game")

    _get_server_lobby().rpc("_client_start_game")

func _get_server_lobby() -> Node:
    return _ls_peer.get_server_root().get_node("Lobby")

puppet func _client_start_game() -> void:
    # Hide lobby
    $MarginContainer.visible = false

func _restart_game() -> void:
    yield(get_tree().create_timer(5), "timeout")
    _server_peer.remove_synchronized_node(_game)
    yield(get_tree().create_timer(1), "timeout")
    _server_start_game()

func _on_server_disconnected():
    var canvas_layer := CanvasLayer.new()
    canvas_layer.layer = 10
    add_child(canvas_layer)

    var dialog := SxFullScreenAcceptDialog.instance() as SxFullScreenAcceptDialog
    dialog.show_title = false
    dialog.message = "Server disconnected.\nYou will be redirected to the title screen."
    dialog.ok_message = "Okay. :("
    canvas_layer.add_child(dialog)
    dialog.connect("confirmed", self, "_go_back_title")
    dialog.show()