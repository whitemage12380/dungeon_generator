require_relative 'map_object'
require_relative 'cursor'

class Passage < MapObject

  def initialize(map:, width:, facing: :east, instructions: nil)
    super(map)
    @width = width
    @cursor = Cursor.new(map, -1, (ylength / 2) - ((width-1) / 2), facing)
    #self[@cursor.pos] = MapObjectSquare.new
    instructions.each { |instruction|
      process_passage_instruction(instruction)
    }
    compact!()
  end

  def process_passage_instruction(instruction, cursor: @cursor)
    # TODO:
    # Chance of secret door
    # Chamber
    # Stairs
    case instruction
    when /^FORWARD [1-9]\d*$/
      distance = (instruction.scan(/\d+/).first.to_i) / 5
      draw_forward(distance)
    when "TURN LEFT"
      draw_forward(@width, cursor: cursor)
      add_wall_width(cursor: cursor)
      cursor.back!(@width - 1)
      cursor.turn!(:left)
      remove_wall_width(cursor: cursor)
    when "TURN RIGHT"
      draw_forward(@width, cursor: cursor)
      add_wall_width(cursor: cursor)
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      remove_wall_width(cursor: cursor)
    when "CONNECTOR"
      connector = Connector.new(self)
      @connectors << connector
      add_connector_width(connector, cursor: cursor)
    # A passage that branches from another passage is either 5ft (16% chance) or 10ft (84% chance).
    # For now I can assume 10ft and add the ability to do 5ft corridors as a future feature.
    when "CONNECTOR LEFT"
      cursor.turn!(:left)
      cursor.shift!(:left)
      connector = Connector.new(self)
      @connectors << connector
      add_connector(connector, 2, 0, cursor: cursor)
      cursor.shift!(:right)
      cursor.turn!(:right)
    when "CONNECTOR RIGHT"
      cursor.turn!(:right)
      cursor.forward!(@width - 1)
      connector = Connector.new(self)
      @connectors << connector
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
  end

  def draw_forward(distance, cursor: @cursor)
    for i in 1..distance do
      cursor.forward!()
      draw_width()
    end
  end

  def draw_width(cursor: @cursor)
    return if not @map.square_available?(cursor.pos)
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
