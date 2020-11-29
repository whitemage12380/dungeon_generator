require_relative 'configuration'
require_relative 'map_object'

class Passage < MapObject

  attr_reader :width

  def initialize(map:, instructions:, description: nil, width: nil, facing: :east, starting_connector: nil, connector_x: nil, connector_y: nil)
    if starting_connector
      width = starting_connector.width if not width
      facing = starting_connector.facing
      connector_x = starting_connector.map_x if not connector_x
      connector_y = starting_connector.map_y if not connector_y
    end
    # For all passage possibilities in the DMG, this size is sufficient.
    # To allow for larger passage styles, this should be modified or able to be overridden
    # by a value in the YAML
    size = 10 + width
    super(map: map, size: size, starting_connector: starting_connector)
    log "Creating #{id_str} at (#{connector_x}, #{connector_y}, facing #{facing})"
    log_indent()
    @width = width
    cursor_pos = initial_cursor_pos(facing)
    @map_offset_x = connector_x ? connector_x - cursor_pos[:x] : 0
    @map_offset_y = connector_y ? connector_y - cursor_pos[:y] : 0
    @cursor = Cursor.new(map: map,
                           x: cursor_pos[:x],
                           y: cursor_pos[:y],
                      facing: facing,
                map_offset_x: @map_offset_x,
                map_offset_y: @map_offset_y)
    initial_cursor = @cursor.copy()
    if width_blocked?
      log "Could not start #{id_str} due to being blocked immediately; not placing connector"
      starting_connector.disconnect()
      starting_connector.map_object.blocked_connector_behavior(starting_connector)
      @status = :failure
      log_outdent()
      return
    end
    instructions.each { |instruction|
      if not process_passage_instruction(instruction)
        # We hit a map edge or another map object. Connect to the map object or wall it off.
        connector = create_connector(@cursor, @width)
        blocked_connector_behavior(connector, type)
        break
      end
    }
    draw_starting_connector(cursor: initial_cursor)
    log "Created #{id_str}"
    @status = :success
    log_outdent
  end

  def id()
    i = map.passages.find_index(self)
    i ? i : map.passages.length
  end

  def initial_cursor_pos(facing)
    case facing
    when :north
      x = (xlength / 2) - (@width - 1)
      y = ylength
    when :east
      x = -1
      y = (ylength / 2) - (@width - 1)
    when :south
      x = (xlength / 2) + (@width - 2)
      y = -1
    when :west
      x = xlength
      y = (ylength / 2) + (@width - 2)
    end
    return {x: x, y: y}
  end

  def width_blocked?(cursor: @cursor, width: @width)
    tmp_cursor = cursor.copy()
    return true unless map.square_available?(tmp_cursor.map_pos_forward)
    for i in 1...@width do
      tmp_cursor.shift!(:right)
      return true unless map.square_available?(tmp_cursor.map_pos_forward)
    end
    return false
  end

  def process_passage_instruction(instruction, cursor: @cursor)
    # TODO:
    # Chance of secret door
    # Stairs
    case instruction
    when /^FORWARD [1-9]\d*$/
      distance = (instruction.scan(/\d+/).first.to_i) / 5
      return false unless draw_forward(distance, cursor: cursor)
    when "TURN LEFT"
      return false unless draw_forward(@width, cursor: cursor)
      add_wall_width(cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
      remove_wall_width(cursor: cursor)
    when "TURN RIGHT"
      return false unless draw_forward(@width, cursor: cursor)
      add_wall_width(cursor: cursor)
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      remove_wall_width(cursor: cursor)
    when "CONNECTOR"
      connector = create_connector(cursor, @width)
      add_connector(connector, 0, cursor: cursor)
    # A passage that branches from another passage is either 5ft (16% chance) or 10ft (84% chance).
    # For now I can assume 10ft and add the ability to do 5ft corridors as a future feature.
    when "CONNECTOR LEFT"
      cursor.turn!(:left)
      cursor.shift!(:left)
      connector = create_connector(cursor, 2)
      add_connector(connector, 0, cursor: cursor)
      cursor.shift!(:right)
      cursor.turn!(:right)
    when "CONNECTOR RIGHT"
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      connector = create_connector(cursor, 2)
      add_connector(connector, 0, cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
    when "DOOR"
      door_width = 2
      door_width = 1 if @width == 1
      door_offset = (@width - 2) / 2
      cursor.shift!(:right, door_offset)
      door = create_door(cursor, door_width)
      add_door(door, 0, cursor: cursor)
      cursor.shift!(:left, door_offset)
    when "DOOR LEFT"
      cursor.turn!(:left)
      cursor.shift!(:left)
      door = create_door(cursor, 2)
      add_door(door, 0, cursor: cursor)
      cursor.shift!(:right)
      cursor.turn!(:right)
    when "DOOR RIGHT"
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      door = create_door(cursor, 2)
      add_door(door, 0, cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
    when /^TEE [1-9]\d*$/
      distance = (instruction.scan(/\d+/).first.to_i) / 5
      return false unless draw_forward(@width, cursor: cursor)
      add_wall_width()
      left_cursor = cursor.copy()
      right_cursor = cursor.copy()
      # Get each cursor into place
      left_cursor.turn!(:left)
      left_cursor.shift!(:left, @width-1)
      right_cursor.turn!(:right)
      right_cursor.forward!(@width-1)
      [left_cursor, right_cursor].each do |c|
        log "#{id_str}: Tee branch at #{c.pos}, #{c.facing}"
        remove_wall_width(cursor: c)
        # Because a tee is desired even if the first branch is blocked,
        # expressly invoke blocked connector behavior instead of returning
        # false and letting initialize handle it
        draw_forward_succeeded = draw_forward(distance, cursor: c)
        connector = create_connector(c, @width)
        if draw_forward_succeeded
          add_connector(connector, 0, cursor: c)
        else
          blocked_connector_behavior(connector, type)
        end
      end
    end
    return true
  end
end
