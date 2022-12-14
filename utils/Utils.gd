extends Object
class_name Utils

const Direction = Enums.Direction
const ALL_DIRECTIONS := [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]

static func add_direction_to_pos(pos: Vector2, direction: int) -> Vector2:
    match direction:
        Direction.LEFT:
            return Vector2(pos.x - 1, pos.y)
        Direction.RIGHT:
            return Vector2(pos.x + 1, pos.y)
        Direction.UP:
            return Vector2(pos.x, pos.y - 1)
        Direction.DOWN:
            return Vector2(pos.x, pos.y + 1)
    return Vector2()

static func rand_direction() -> int:
    return SxRand.choice_array(ALL_DIRECTIONS)