extends Control

onready var _map1_btn := $MarginContainer/VBoxContainer/VBoxContainer/Map1 as Button
onready var _map2_btn := $MarginContainer/VBoxContainer/VBoxContainer/Map2 as Button
onready var _random_btn := $MarginContainer/VBoxContainer/VBoxContainer/Random as Button

func _ready() -> void:
    _map1_btn.connect("pressed", self, "_load_level", ["Map01"])
    _map2_btn.connect("pressed", self, "_load_level", ["Map02"])
    _random_btn.connect("pressed", self, "_load_level", ["random"])

func _load_level(name: String) -> void:
    GameData.set_map_name(name)
    GameSceneTransitioner.fade_to_scene_path("res://screens/Game.tscn")