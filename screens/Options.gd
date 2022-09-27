extends Control

onready var _back_btn := $MarginContainer/VBoxContainer/Back as Button
onready var _username_field := $MarginContainer/VBoxContainer/VBoxContainer/Username/LineEdit as LineEdit

func _ready() -> void:
    _back_btn.connect("pressed", self, "_go_back")
    _username_field.text = GameData.player_username

func _go_back() -> void:
    var new_username = _username_field.text.strip_edges()
    if new_username != "":
        GameData.set_player_username(new_username)
    GameSceneTransitioner.fade_to_scene_path("res://screens/Title.tscn")
