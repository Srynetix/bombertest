extends Control

onready var _title := $MarginContainer/VBoxContainer/Title as Label
onready var _solo_btn := $MarginContainer/VBoxContainer/VBoxContainer/Solo as Button
onready var _local1v1_btn := $MarginContainer/VBoxContainer/VBoxContainer/Local1v1 as Button
onready var _online_btn := $MarginContainer/VBoxContainer/VBoxContainer/OnlineMultiplayer as Button

func _ready() -> void:
    _title.rect_pivot_offset = _title.rect_size / 2

    _solo_btn.connect("pressed", self, "_start_game_solo")
    _local1v1_btn.connect("pressed", self, "_start_game_local")
    _online_btn.connect("pressed", self, "_start_game_online")

func _start_game_solo() -> void:
    GameData.set_game_mode(Enums.GameMode.SOLO)
    GameSceneTransitioner.fade_to_scene_path("res://screens/Game.tscn")

func _start_game_local() -> void:
    GameData.set_game_mode(Enums.GameMode.LOCAL)
    GameSceneTransitioner.fade_to_scene_path("res://screens/Game.tscn")

func _start_game_online() -> void:
    pass