extends SxLoadCache

func load_resources() -> void:
    _logger.set_max_log_level(SxLog.LogLevel.DEBUG)

    store_resource("FXBoom", "res://assets/local/fx/boom.wav")
    store_resource("FXPush", "res://assets/local/fx/push.wav")
    store_resource("FXDied", "res://assets/local/fx/died.wav")
    store_resource("FXPowerup", "res://assets/local/fx/powerup.wav")
    store_resource("FXClick", "res://assets/local/fx/click.wav")

    store_scene("TempAudioFX", "res://scenes/TempAudioFX.tscn")