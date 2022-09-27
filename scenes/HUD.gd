extends CanvasLayer
class_name HUD

const PlayerHUDScene := preload("res://scenes/PlayerHUD.tscn")

onready var _time_limit := $MarginContainer/TimeLimit as Label
onready var _win := $MarginContainer/Win as Label
onready var _win_anim_player := $WinAnimationPlayer as AnimationPlayer
onready var _top_bar := $TopBar as HBoxContainer
onready var _bottom_bar := $BottomBar as HBoxContainer

var _huds := {}

###########
# Lifecycle

func _ready() -> void:
    _time_limit.text = ""


################
# Public methods

func setup_player_hud(initial_score: Dictionary, names: Dictionary) -> void:
    var count := 0
    for idx in initial_score:
        var instance := PlayerHUDScene.instance() as PlayerHUD
        instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
        instance.player_name = names[idx]

        if count >= 2:
            instance.inverted = true
            _bottom_bar.add_child(instance)
        else:
            _top_bar.add_child(instance)

        _huds[idx] = instance
        instance.update_score(initial_score[idx])
        count += 1

func update_player_score(player_idx: int, score: int) -> void:
    _huds[player_idx].update_score(score)

func add_player_item(player_idx: int, item_type: int) -> void:
    _huds[player_idx].add_item(item_type)

func update_hud(time: float) -> void:
    _time_limit.text = "%d'" % int(time)

func show_ready() -> void:
    yield(_show_win_message("Ready?"), "completed")
    yield(_show_win_message("Set?"), "completed")
    yield(_show_win_message("Go!"), "completed")
    _win.text = ""

func show_win(player_name: String) -> void:
    _show_win_message("%s WINS!" % player_name)

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
    yield(get_tree(), "idle_frame")

    _win.modulate = color
    _win.rect_pivot_offset = _win.rect_size / 2
    _win_anim_player.play("wins")
    yield(_win_anim_player, "animation_finished")