# Role:
#   A bomb / power bomb, spawned by players in the game.

extends Sprite
class_name Bomb

export var power_bomb := false

onready var _animation_player := $AnimationPlayer as AnimationPlayer
onready var _ignition_timer := $Ignition as Timer
onready var _power_particles := $PowerParticles as CPUParticles2D

signal explode()

var spawner: Node = null

var _triggered := false

###########
# Lifecycle

func _ready() -> void:
    _ignition_timer.connect("timeout", self, "trigger")
    _animation_player.play("charging")
    _power_particles.emitting = power_bomb

################
# Public methods

func trigger() -> void:
    if _triggered:
        return

    _triggered = true
    _ignition_timer.stop()
    _explode()

func freeze() -> void:
    _ignition_timer.stop()

#########
# Helpers

func _explode() -> void:
    emit_signal("explode")
    queue_free()
