require_relative 'map_object'


class Passage < MapObject

  attr_reader :width

  def initialize(map:, width: nil, facing: :east, starting_connector: nil, connector_x: nil, connector_y: nil, instructions: nil)
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
    instructions.each { |instruction|
      if not process_passage_instruction(instruction)
        # We hit a map edge or another map object; wall it off and be done
        add_wall_width()
        break
      end
    }
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

  def process_passage_instruction(instruction, cursor: @cursor)
    # TODO:
    # Chance of secret door
    # Chamber
    # Stairs
    case instruction
    when /^FORWARD [1-9]\d*$/
      distance = (instruction.scan(/\d+/).first.to_i) / 5
      return false if not draw_forward(distance)
    when "TURN LEFT"
      return false if not draw_forward(@width, cursor: cursor)
      add_wall_width(cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
      remove_wall_width(cursor: cursor)
    when "TURN RIGHT"
      return false if not draw_forward(@width, cursor: cursor)
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
    end
    return true
  end

  def remove_wall_width(cursor: @cursor)
    self[cursor.pos].remove_wall(cursor.facing)
    for i in 1...@width do
      cursor.shift!(:right)
      self[cursor.pos].remove_wall(cursor.facing)
    end
    cursor.shift!(:left, @width-1)
  end

  #def add_connector_width(connector, cursor: @cursor)
  #  add_connector(connector, @width, 0, cursor: cursor)
  #end
end
