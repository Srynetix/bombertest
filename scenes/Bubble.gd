# Unused yet.
extends Node2D
class_name Bubble

onready var _animation_player := $AnimationPlayer as AnimationPlayer
onready var _label := $Label as Label
onready var _sprite := $Sprite as Sprite

var player_index := 1
var camera: Camera2D = null
var target_node: Node2D = null

###########
# Lifecycle

func _ready() -> void:
    visible = false
    _label.text = "P%d" % player_index

func _process(_delta: float) -> void:
    if camera == null || target_node == null || !is_instance_valid(target_node):
        if visible:
            _fade_out()
        return

    var show_bubble := false
    var bubble_offset := _get_size() / 1.5
    var target_coords := target_node.position
    var camera_coords := camera.position * camera.zoom
    var vp_size := get_viewport_rect().size * camera.zoom

    if target_coords.x > camera_coords.x + vp_size.x:
        position.x = camera_coords.x + vp_size.x - bubble_offset.x
        show_bubble = true
    elif target_coords.x < camera_coords.x:
        position.x = camera_coords.x + bubble_offset.x
        show_bubble = true
    else:
        position.x = target_coords.x

    if target_coords.y > camera_coords.y + vp_size.y:
        position.y = camera_coords.y + vp_size.y - bubble_offset.y
        show_bubble = true
    elif target_coords.y < camera_coords.y:
        position.y = camera_coords.y + bubble_offset.y
        show_bubble = true
    else:
        position.y = target_coords.y

    _rotate_towards(target_coords)

    if show_bubble:
        if !visible:
            _fade_in()
    else:
        if visible:
            _fade_out()

#########
# Helpers

func _fade_in() -> void:
    _animation_player.play("fade_in")

func _fade_out() -> void:
    _animation_player.play("fade_out")

func _rotate_towards(point: Vector2) -> void:
    _sprite.rotation = point.angle_to_point(position)

func _get_size() -> Vector2:
    return _sprite.texture.get_size() * _sprite.scale