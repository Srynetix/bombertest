extends Sprite
class_name Player

signal move(direction)
signal spawn_bomb()
signal push_bomb(direction)
signal exploded()

enum MoveState {
    IDLE,
    MOVING
}

const Direction = Enums.Direction

const ANIMATION_MAP := {
    MoveState.IDLE: {
        Direction.LEFT: "idle_left",
        Direction.RIGHT: "idle_right",
        Direction.UP: "idle_up",
        Direction.DOWN: "idle_down",
    },
    MoveState.MOVING: {
        Direction.LEFT: "moving_left",
        Direction.RIGHT: "moving_right",
        Direction.UP: "moving_up",
        Direction.DOWN: "moving_down",
    }
}

export var player_index := 1
export var player_color := Color.white

onready var _animation_player := $AnimationPlayer as AnimationPlayer
onready var _label := $Label as Label

var _direction: int = Direction.DOWN
var _move_state: int = MoveState.IDLE
var _locked := false
var _exploded := false
var _player_input: PlayerInput

func _ready() -> void:
    self_modulate = player_color
    _label.text = "P%d" % player_index
    _update_animation_state()

    # Get input
    if has_node("PlayerInput"):
        _player_input = get_node("PlayerInput")
    else:
        _player_input = LocalPlayerInput.new()
        _player_input.name = "PlayerInput"
        _player_input.player_index = player_index
        add_child(_player_input)

func _is_player_action_pressed(key: String) -> bool:
    return _player_input.keys[key]

func _process(_delta: float) -> void:
    if _exploded:
        return

    var direction := Vector2()

    if _is_player_action_pressed("move_left"):
        direction.x -= 1

    if _is_player_action_pressed("move_right"):
        direction.x += 1

    if _is_player_action_pressed("move_up"):
        direction.y -= 1

    if _is_player_action_pressed("move_down"):
        direction.y += 1

    if direction.y > 0:
        _move(Direction.DOWN)
    elif direction.y < 0:
        _move(Direction.UP)
    else:
        if direction.x > 0:
            _move(Direction.RIGHT)
        elif direction.x < 0:
            _move(Direction.LEFT)
        else:
            _stay_idle()

    if _is_player_action_pressed("bomb"):
        _spawn_bomb()

    if _is_player_action_pressed("push"):
        _push_bomb()

func _move(direction: int) -> void:
    if !_locked:
        _direction = direction
        _move_state = MoveState.MOVING
        _update_animation_state()
        emit_signal("move", _direction)

func _spawn_bomb() -> void:
    emit_signal("spawn_bomb")

func _push_bomb() -> void:
    emit_signal("push_bomb", _direction)

func lock() -> void:
    _locked = true

func unlock() -> void:
    _locked = false

func explode() -> void:
    if _exploded:
        return

    _exploded = true
    _animation_player.play("explode")
    emit_signal("exploded")
    yield(_animation_player, "animation_finished")
    queue_free()

func _stay_idle() -> void:
    _move_state = MoveState.IDLE
    _update_animation_state()

func _update_animation_state() -> void:
    _animation_player.play(ANIMATION_MAP[_move_state][_direction])