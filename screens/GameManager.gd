# Simple node used as a wrapper for the Game scene.
# It handles game auto-restart once it's finished.
extends Node2D
class_name GameManager

const GameScene := preload("res://screens/Game.tscn")

var game_instance: Node = null

func _ready() -> void:
    GameData.reset_scores()
    _new_game()

func _new_game() -> void:
    game_instance = GameScene.instance()
    game_instance.connect("game_over", self, "_restart_game")
    add_child(game_instance)

func _restart_game() -> void:
    yield(get_tree().create_timer(5), "timeout")
    game_instance.queue_free()
    _new_game()