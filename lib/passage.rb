require_relative 'map_object'
require_relative 'cursor'

class Passage < MapObject

  def initialize(map, width, instructions)
    super(map)
    @width = width
    @cursor = Cursor.new(map, -1, (ylength / 2) - ((width-1) / 2), :east)
    #self[@cursor.pos] = MapObjectSquare.new
    instructions.each { |instruction|
      process_passage_instruction(instruction)
    }
  end

  def process_passage_instruction(instruction)
    case instruction
    when /^FORWARD [1-9]\d*$/
      distance = (instruction.scan(/\d+/).first.to_i) / 5
      draw_forward(distance)
    when "TURN LEFT"
      draw_forward(@width)
      add_wall_width()
      @cursor.back!(@width - 1)
      @cursor.turn!(:left)
      remove_wall_width()
    when "TURN RIGHT"
      draw_forward(@width)
      add_wall_width()
      @cursor.turn!(:right)
      @cursor.forward!(@width - 1)
      remove_wall_width()
    when "CONNECTOR"
      connector = Connector.new(self)
      @connectors << connector
      add_connector_width(connector)
    end
  end

  def draw_forward(distance)
    for i in 1..distance do
      @cursor.forward!()
      draw_width()
    end
  end

  def draw_width()
    return if not @map.square_available?(@cursor.pos)
    self[@cursor.pos] = MapObjectSquare.new({@cursor.left => :wall})
    for i in 1...@width do
      @cursor.shift!(:right)
      self[@cursor.pos] = MapObjectSquare.new()
    end
    self[@cursor.pos].add_wall(@cursor.right)
    @cursor.shift!(:left, @width-1)
  end

  def add_wall_width()
    self[@cursor.pos].add_wall(@cursor.facing)
    for i in 1...@width do
      @cursor.shift!(:right)
      self[@cursor.pos].add_wall(@cursor.facing)
    end
    @cursor.shift!(:left, @width-1)
  end

  def remove_wall_width()
    self[@cursor.pos].remove_wall(@cursor.facing)
    for i in 1...@width do
      @cursor.shift!(:right)
      self[@cursor.pos].remove_wall(@cursor.facing)
    end
    @cursor.shift!(:left, @width-1)
  end

  def add_connector_width(connector)
    self[@cursor.pos].add_connector(@cursor.facing(:left), connector)
    for i in 1...@width do
      @cursor.shift!(:right)
      self[@cursor.pos].add_connector(@cursor.facing(:left), connector)
    end
    @cursor.shift!(:left, @width-1)
  end
end
