extends Node2D
class_name Bubble

onready var _animation_player := $AnimationPlayer as AnimationPlayer
onready var _label := $Label as Label
onready var _sprite := $Sprite as Sprite

var player_index := 1

func _ready() -> void:
    visible = false
    _label.text = "P%d" % player_index

func fade_in() -> void:
    _animation_player.play("fade_in")

func fade_out() -> void:
    _animation_player.play("fade_out")

func rotate_towards(point: Vector2) -> void:
    _sprite.rotation = point.angle_to_point(position)

func get_size() -> Vector2:
    return _sprite.texture.get_size() * _sprite.scale