extends Node2D
class_name Item

const PowerBombTexture := preload("res://assets/local/item_power.png")
const PushTexture := preload("res://assets/local/item_push.png")
const BombTexture := preload("res://assets/local/item_bomb.png")

enum ItemType {
    Bomb,
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
    _sprite.texture = get_item_texture(item_type)

################
# Public methods

static func get_item_texture(itype: int) -> Texture:
    match itype:
        ItemType.Bomb:
            return BombTexture
        ItemType.PowerBomb:
            return PowerBombTexture
        _:
            return PushTexture

static func random_item_type() -> int:
    return SxRand.range_i(0, ItemType.Push + 1)

func pickup() -> void:
    if _picked:
        return

    _picked = true
    _anim_player.play("pickup")
    yield(_anim_player, "animation_finished")
    queue_free()