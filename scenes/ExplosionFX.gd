extends CPUParticles2D
class_name ExplosionFX

func _ready():
    emitting = true
    yield(get_tree().create_timer(lifetime), "timeout")
    queue_free()