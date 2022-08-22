# SxGameDatas are used for global state handling and saving/loading datas.
extends "res://addons/sxgd/nodes/utils/SxGameData/SxGameData.gd"

const GameMode = Enums.GameMode

var game_mode := GameMode.LOCAL as int
var map_name := "random"

func set_game_mode(mode: int) -> void:
    game_mode = mode

func set_map_name(name: String) -> void:
    map_name = name