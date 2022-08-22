extends Node2D
class_name Item

const PowerBombTexture := preload("res://assets/local/item_power.png")
const PushTexture := preload("res://assets/local/item_push.png")

enum ItemType {
    PowerBomb,
    Push
}

export var item_type := ItemType.PowerBomb

onready var _sprite := $Sprite as Sprite
onready var _anim_player := $AnimationPlayer as AnimationPlayer

var _picked := false

###########
# Lifecycle

func _ready() -> void:
    match item_type:
        ItemType.PowerBomb:
            _sprite.texture = PowerBombTexture
        ItemType.Push:
            _sprite.texture = PushTexture

################
# Public methods

static func random_item_type() -> int:
    return SxRand.range_i(0, ItemType.Push + 1)

func pickup() -> void:
    if _picked:
        return

    _picked = true
    _anim_player.play("pickup")
    yield(_anim_player, "animation_finished")
    queue_free()