extends AudioStreamPlayer
class_name TempAudioFX

export var min_pitch_offset := 1.0
export var max_pitch_offset := 1.0

func _ready() -> void:
    pitch_scale = get_random_pitch()
    play()
    yield(self, "finished")
    queue_free()

func get_random_pitch() -> float:
    return rand_range(min_pitch_offset, max_pitch_offset)