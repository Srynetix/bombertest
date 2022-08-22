# Local player input, with local key bindings.
# Use a "p<id>_<action>" nomenclature, e.g moving up for Player 2 equals: "p2_move_up"
extends "res://scenes/Player/PlayerInput.gd"
class_name LocalPlayerInput

var player_index: int = 1

###########
# Lifecycle

func _process(_delta: float) -> void:
    _reset()

    for k in ["move_left", "move_right", "move_up", "move_down"]:
        keys[k] = _is_player_action_pressed(k)

    for k in ["bomb", "push"]:
        keys[k] = _is_player_action_just_pressed(k)

#########
# Helpers

func _get_player_action_key(key: String) -> String:
    return "p%d_%s" % [player_index, key]

func _is_player_action_pressed(key: String) -> bool:
    return Input.is_action_pressed(_get_player_action_key(key))

func _is_player_action_just_pressed(key: String) -> bool:
    return Input.is_action_just_pressed(_get_player_action_key(key))