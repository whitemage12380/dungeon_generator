require_relative 'configuration'
require_relative 'map_object'

class Stairs < MapObject

  def initialize(map:, width: 2, length: 2, facing: nil, starting_connector: nil,  connector_x: nil, connector_y: nil, entrance_width: nil)
    size = [width, length].max
    super(map: map, size: size, starting_connector: starting_connector)
    log "Creating #{id_str} with intended dimensions: #{width}x#{length}"
    if starting_connector
      connector_x = starting_connector.map_x if not connector_x
      connector_y = starting_connector.map_y if not connector_y
      facing = starting_connector.facing if not facing
      entrance_width = starting_connector.width if not entrance_width
    end
    @width = width
    @length = length
    @facing = facing
    cursor_pos = initial_cursor_pos(facing)
    @map_offset_x = connector_x ? connector_x - cursor_pos[:x] : 0
    @map_offset_y = connector_y ? connector_y - cursor_pos[:y] : 0
    @cursor = Cursor.new(map: map,
                           x: cursor_pos[:x],
                           y: cursor_pos[:y],
                      facing: facing,
                map_offset_x: @map_offset_x,
                map_offset_y: @map_offset_y
    )
    if draw_stairs(cursor, width, length)
      log "Created #{id_str}"
      @status = :success
    else
      log "#{id_str}: Failed to create stairs"
      if starting_connector
        starting_connector.disconnect()
        starting_connector.map_object.blocked_connector_behavior(starting_connector)
      end
      @status = :failure
    end
  end

  def id()
    map.stairs.find_index(self)
  end

  # Distance from West to East
  def abs_width()
    case @facing
    when :north, :south; @width
    when :east, :west;   @length
    end
  end

  # Distance from North to South
  def abs_length()
    case @facing
    when :north, :south; @length
    when :east, :west;   @width
    end
  end

  def initial_cursor_pos(facing)
      # Return a position that, from the given facing, is at the back-most left-most square of the chamber.
    case facing
    when :north
      x = 0
      y = @length
    when :east
      x = -1
      y = 0
    when :south
      x = @width - 1
      y = -1
    when :west
      x = @length
      y = @width - 1
    end
    return {x: x, y: y}
  end

  def draw_stairs(cursor = @cursor, width = @width, length = @length)
    initial_cursor = cursor.copy()
    return false unless draw_forward(length, width: width, cursor: cursor)
    add_wall_width(cursor: cursor)
    draw_starting_connector(cursor: initial_cursor)
    return true
  end

end