extends Control

func _ready() -> void:
    if GameData.autostart_client || GameData.autostart_server:
        GameSceneTransitioner.fade_to_scene_path("res://screens/networking/Lobby.tscn", 10)
    elif GameData.autostart_solo:
        GameSceneTransitioner.fade_to_scene_path("res://screens/GameManager.tscn")
    else:
        GameSceneTransitioner.fade_to_scene_path("res://screens/Title.tscn", 10)