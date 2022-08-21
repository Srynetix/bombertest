extends "res://scenes/PlayerInput.gd"
class_name LocalPlayerInput

var player_index: int = 1

func _get_player_action_key(key: String) -> String:
    return "p%d_%s" % [player_index, key]

func _is_player_action_pressed(key: String) -> bool:
    return Input.is_action_pressed(_get_player_action_key(key))

func _is_player_action_just_pressed(key: String) -> bool:
    return Input.is_action_just_pressed(_get_player_action_key(key))

func _process(_delta: float) -> void:
    _reset()

    for k in ["move_left", "move_right", "move_up", "move_down"]:
        keys[k] = _is_player_action_pressed(k)

    for k in ["bomb", "push"]:
        keys[k] = _is_player_action_just_pressed(k)