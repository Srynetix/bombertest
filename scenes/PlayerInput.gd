extends Node
class_name PlayerInput

var keys := {
    "move_left": false,
    "move_right": false,
    "move_up": false,
    "move_down": false,
    "bomb": false,
    "push": false
}

func _reset():
    for k in keys:
        keys[k] = false
