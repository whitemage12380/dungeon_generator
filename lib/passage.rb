require_relative 'map_object'
require_relative 'cursor'

class Passage < MapObject

  attr_reader :width, :cursor

  def initialize(map:, width:, facing: :east, connector_x: nil, connector_y: nil, instructions: nil)
    # For all passage possibilities in the DMG, this size is sufficient.
    # To allow for larger passage styles, this should be modified or able to be overridden
    # by a value in the YAML
    size = 10 + width
    super(map, size)
    @width = width
    cursor_pos = initial_cursor_pos(facing)
    # TODO: This may be 1 square off, make sure this is right
    @map_offset_x = connector_x - cursor_pos[:x]
    @map_offset_y = connector_y - cursor_pos[:y]
    @cursor = Cursor.new(map: map, x: cursor_pos[:x], y: cursor_pos[:y], facing: facing, map_offset_x: @map_offset_x, map_offset_y: @map_offset_y)
    instructions.each { |instruction|
      if not process_passage_instruction(instruction)
        add_wall_width()
        break
      end
    }
    #compact!()
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
      connector = create_connector()
      add_connector_width(connector, cursor: cursor)
    # A passage that branches from another passage is either 5ft (16% chance) or 10ft (84% chance).
    # For now I can assume 10ft and add the ability to do 5ft corridors as a future feature.
    when "CONNECTOR LEFT"
      cursor.turn!(:left)
      cursor.shift!(:left)
      connector = create_connector(2)
      add_connector(connector, 2, 0, cursor: cursor)
      cursor.shift!(:right)
      cursor.turn!(:right)
    when "CONNECTOR RIGHT"
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      connector = create_connector(2)
      add_connector(connector, 2, 0, cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
    when "DOOR"
      door_width = 2
      door_width = 1 if @width == 1
      door_offset = (@width - 2) / 2
      door = Door.new(self)
      @doors << door
      add_door(door, door_width, door_offset, cursor: cursor)
    when "DOOR LEFT"
      cursor.turn!(:left)
      cursor.shift!(:left)
      door = Door.new(self)
      @doors << door
      add_door(door, 2, 0, cursor: cursor)
      cursor.shift!(:right)
      cursor.turn!(:right)
    when "DOOR RIGHT"
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      door = Door.new(self)
      @doors << door
      add_door(door, 2, 0, cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
    when Array
      new_cursor = Cursor.new(map, cursor.x.clone, cursor.y.clone, cursor.facing.clone)
      instruction.each { |split_instruction|
        process_passage_instruction(split_instruction, cursor: new_cursor)
      }
    end
    return true
  end

  def create_connector(width = @width)
    connector = Connector.new(map_object: self,
                                  square: self[cursor.pos],
                                   map_x: @cursor.map_x.clone,
                                   map_y: @cursor.map_y.clone,
                                  facing: @cursor.facing.clone,
                                   width: width)
    @connectors << connector
    return connector
  end

  def draw_forward(distance, cursor: @cursor)
    for i in 1..distance do
      return false if not @map.square_available?(cursor.map_pos_forward)
      cursor.forward!()
      draw_width()
    end
    return true
  end

  def draw_width(cursor: @cursor)
    #return false if not @map.square_available?(cursor.map_pos)
    self[@cursor.pos] = MapObjectSquare.new({@cursor.left => :wall})
    for i in 1...@width do
      @cursor.shift!(:right)
      self[@cursor.pos] = MapObjectSquare.new()
    end
    self[@cursor.pos].add_wall(@cursor.right)
    @cursor.shift!(:left, @width-1)
  end

  def add_wall_width(cursor: @cursor)
    return if not square_empty?(cursor.pos_forward)
    self[cursor.pos].add_wall(cursor.facing)
    for i in 1...@width do
      cursor.shift!(:right)
      self[cursor.pos].add_wall(cursor.facing)
    end
    cursor.shift!(:left, @width-1)
  end

  def remove_wall_width(cursor: @cursor)
    self[cursor.pos].remove_wall(cursor.facing)
    for i in 1...@width do
      cursor.shift!(:right)
      self[cursor.pos].remove_wall(cursor.facing)
    end
    cursor.shift!(:left, @width-1)
  end

  def add_connector_width(connector, cursor: @cursor)
    self[cursor.pos].add_connector(cursor.facing, connector)
    for i in 1...@width do
      cursor.shift!(:right)
      self[cursor.pos].add_connector(cursor.facing, connector)
    end
    cursor.shift!(:left, @width-1)
  end

  def add_connector(connector, connector_width, connector_offset, cursor: @cursor)
    cursor.shift!(:right, connector_offset)
    self[cursor.pos].add_connector(cursor.facing, connector)
    for i in 1...connector_width do
      cursor.shift!(:right)
      self[cursor.pos].add_connector(cursor.facing, connector)
    end
    cursor.shift!(:left, connector_width + connector_offset - 1)
  end

  def add_door(door, door_width, door_offset, cursor: @cursor)
    cursor.shift!(:right, door_offset)
    self[cursor.pos].add_door(cursor.facing, door)
    for i in 1...door_width do
      cursor.shift!(:right)
      self[cursor.pos].add_door(cursor.facing, door)
    end
    cursor.shift!(:left, door_width + door_offset - 1)
  end
end
