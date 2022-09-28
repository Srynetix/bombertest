# SxGameDatas are used for global state handling and saving/loading datas.
extends SxGameData

const GameMode = Enums.GameMode

var player_username: String
var game_mode := GameMode.SOLO as int
var game_max_players := 4
var game_human_players := 1
var map_name := "random"
var last_scores := {}

var autostart_solo := false
var autostart_server := false
var autostart_server_port := 12341
var autostart_client := false
var autostart_client_server_ip := "127.0.0.1:12341"
var use_websockets := false

const SAVE_FILE := "user://save.dat"

func _ready():
    load_from_disk(SAVE_FILE)
    player_username = load_value("player_username", "Player")

    if OS.get_name() == "HTML5":
        use_websockets = true

func set_game_mode(mode: int) -> void:
    game_mode = mode

func set_map_name(name: String) -> void:
    map_name = name

func set_player_username(name: String) -> void:
    player_username = name
    store_value("player_username", name)
    persist_to_disk(SAVE_FILE)

func update_scores(scores: Dictionary) -> void:
    last_scores = scores

func add_player_score(player_index: int, delta: int) -> int:
    last_scores[player_index] += delta
    return last_scores[player_index]

func reset_scores() -> void:
    last_scores.clear()