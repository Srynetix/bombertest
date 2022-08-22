extends CanvasLayer
class_name HUD

onready var _time_limit := $MarginContainer/TimeLimit as Label
onready var _win := $MarginContainer/Win as Label
onready var _win_anim_player := $WinAnimationPlayer as AnimationPlayer

###########
# Lifecycle

func _ready() -> void:
    _time_limit.text = ""

################
# Public methods

func update_hud(time: float) -> void:
    _time_limit.text = "%d'" % int(time)

func show_ready() -> void:
    yield(_show_win_message("Ready?"), "completed")
    yield(_show_win_message("Set?"), "completed")
    yield(_show_win_message("Go!"), "completed")
    _win.text = ""

func show_win(player_index: int) -> void:
    _show_win_message("P%d WINS!" % player_index)

func show_draw() -> void:
    _show_win_message("DRAW!")

func show_time_out() -> void:
    _show_win_message("TIME!")

#########
# Helpers

func _show_win_message(msg: String) -> void:
    # The "idle_frame" dance is needed, because when setting the "text" attribute,
    # the label "rect_size" is not yet computed, so the "rect_pivot_offset" will not be
    # correctly set.
    #
    # Waiting for "idle_frame" will ensure the label has the correct size.

    var color := _win.modulate
    _win.modulate = Color.transparent
    _win.text = msg
    yield(get_tree(), "idle_frame")

    _win.modulate = color
    _win.rect_pivot_offset = _win.rect_size / 2
    _win_anim_player.play("wins")
    yield(_win_anim_player, "animation_finished")