extends Object
class_name MapRandomizer

var _bg_tilemap: TileMap
var _mg_tilemap: TileMap
var _tileset: TileSet

func _init(background: TileMap, middleground: TileMap) -> void:
    _bg_tilemap = background
    _mg_tilemap = middleground
    _tileset = _mg_tilemap.tile_set

func randomize(map_size: Vector2) -> void:
    var bg_tile := _tileset.find_tile_by_name("background")
    var wall_tile := _tileset.find_tile_by_name("wall")
    var crate_tile := _tileset.find_tile_by_name("crate")
    var player_tile := _tileset.find_tile_by_name("player")
    assert(map_size.x > 10 && map_size.y > 10, "map size should be greater than 10x10")

    # Draw background
    for x in range(map_size.x):
        for y in range(map_size.y):
            _bg_tilemap.set_cell(x, y, bg_tile)

    # Draw walls
    for y in [0, map_size.y - 1]:
        for x in range(map_size.x):
            _mg_tilemap.set_cell(x, y, wall_tile)
    for x in [0, map_size.x - 1]:
        for y in range(map_size.y):
            _mg_tilemap.set_cell(x, y, wall_tile)

    # Draw players
    _mg_tilemap.set_cell(1, 1, player_tile)
    _mg_tilemap.set_cell(int(map_size.x) - 2, int(map_size.y) - 2, player_tile)

    var blocked_positions = {
        Vector2(2, 1): true,
        Vector2(1, 2): true,
        Vector2(map_size.x - 3, map_size.y - 2): true,
        Vector2(map_size.x - 2, map_size.y - 3): true,
    }

    # Put random tiles, 50% chance of a crate
    # Quite stupid algorithm, needs some "procedural" things
    for x in range(map_size.x):
        for y in range(map_size.y):
            if SxRand.chance_bool(25):
                if _mg_tilemap.get_cell(x, y) == -1:
                    if !blocked_positions.has(Vector2(x, y)):
                        var tile_to_draw := crate_tile
                        if SxRand.chance_bool(25):
                            tile_to_draw = wall_tile
                        _mg_tilemap.set_cell(x, y, tile_to_draw)