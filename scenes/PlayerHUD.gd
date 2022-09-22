extends MarginContainer
class_name PlayerHUD

onready var _name := $HBoxContainer/Name as Label
onready var _score := $HBoxContainer/Score as Label
onready var _items := $Items as HBoxContainer

var player_name: String
var inverted := false

var _known_items := {}

func _ready() -> void:
    _name.text = player_name

    if inverted:
        _name.size_flags_vertical = SIZE_SHRINK_END
        _score.size_flags_vertical = SIZE_SHRINK_END
        _items.size_flags_vertical = SIZE_SHRINK_END

func update_score(score: int) -> void:
    _score.text = str(score)

func add_item(item_type: int) -> void:
    if !_has_item(item_type):
        var txrect := TextureRect.new()
        txrect.texture = Item.get_item_texture(item_type)
        txrect.size_flags_horizontal = SIZE_SHRINK_CENTER
        txrect.size_flags_vertical = SIZE_SHRINK_CENTER
        _items.add_child(txrect)
        _known_items[item_type] = true

func _has_item(item_type: int) -> bool:
    return _known_items.has(item_type)
