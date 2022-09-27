extends PlayerInput
class_name NetPlayerInput

var player_index: int

func _process(_delta: float) -> void:
    _reset()

    if SxNetwork.is_network_server(get_tree()):
        var rpc_service := SxRPCService.get_from_tree(get_tree()) as SxRPCService
        var sync_input := rpc_service.sync_input

        for k in ["move_left", "move_right", "move_up", "move_down"]:
            keys[k] = sync_input.is_action_pressed(self, "p1_%s" % k)

        for k in ["bomb", "push"]:
            keys[k] = sync_input.is_action_just_pressed(self, "p1_%s" % k)