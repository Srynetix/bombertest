# Player input management.
# Made to be subclassed, pressed key status is contained in the "keys" dictionary.
extends Node
class_name PlayerInput

# Input key status
var keys := {
    "move_left": false,
    "move_right": false,
    "move_up": false,
    "move_down": false,
    "bomb": false,
    "push": false
}

#########
# Helpers

func _reset():
    for k in keys:
        keys[k] = false
