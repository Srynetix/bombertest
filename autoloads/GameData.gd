extends "res://addons/sxgd/nodes/utils/SxGameData/SxGameData.gd"

const GameMode = Enums.GameMode

var game_mode := GameMode.LOCAL as int

func set_game_mode(mode: int) -> void:
    game_mode = mode