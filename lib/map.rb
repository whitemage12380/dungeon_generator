require_relative 'configuration'
require_relative 'map_generator'
require_relative 'map_object'
require_relative 'passage'
require_relative 'chamber'

class Map
  include DungeonGeneratorHelper
  attr_accessor :grid, :map_objects

  MAX_SIZE = 500

  def initialize(size = MAX_SIZE)
    @grid = Array.new(size) {Array.new(size)}
    @map_objects = Array.new
  end

  def size()
    return @grid.length
  end

  def [] (x, y)
    @grid[x][y]
  end

  def []= (x, y, value)
    @grid[x][y] = value
  end

  #def [] (coordinates)
  #  @grid[coordinates[:x]][coordinates[:y]]
  #end
#
#  def []=(coordinates, value)
#    @grid[coordinates[:x]][coordinates[:y]] = value
#  end

  def square(x:, y:)
    return nil if @grid.nil? or @grid[x].nil?
    @grid[x][y]
  end

  def square_available?(x:, y:)
    return false if x < 0 or y < 0
    return false if xlength <= x or ylength <= y
    return false if @grid[x][y]
    return true
  end

  def xlength()
    return @grid.length
  end
  def ylength()
    return @grid[0].length
  end

  def passages()
    map_objects.select { |mo| mo.kind_of? Passage }
  end

  def chambers()
    map_objects.select { |mo| mo.kind_of? Chamber }
  end

  def add_passage(passage: nil, connector: nil, width: nil, x: nil, y: nil, facing: nil, instructions: nil)
    # If given a connector (which outside of dev/testing will always be true),
    # it can figure out x, y, and facing and it can randomize width based on the connector as well.
    # The passage can then do the rest of the work.
    # The passage itself should figure out its instructions if not given.
    #if connector
    #  width = connector.width if not width
    #  x = connector.map_x if not x
    #  y = connector.map_y if not y
    #  facing = connector.facing if not facing
    #end
    if passage.nil?
      if connector
        passage = Passage.new(map: self, starting_connector: connector, instructions: instructions)
      else
        passage = Passage.new(map: self, width: width, facing: facing, connector_x: x, connector_y: y, instructions: instructions)
      end
    end
    return nil unless passage.success?
    @map_objects << passage
    draw_map_object(passage)
    return passage
  end

  def add_chamber(connector: nil, width: nil, length: nil, x: nil, y: nil, facing: nil, entrance_width: nil)
    if connector
      chamber = Chamber.new(map: self, starting_connector: connector, width: width, length: length)
    else
      chamber = Chamber.new(map: self, width: width, length: length, facing: facing, connector_x: x, connector_y: y, entrance_width: entrance_width)
    end
    return nil unless chamber.success?
    @map_objects << chamber
    draw_map_object(chamber)
    return chamber
  end

  def draw_map_object(map_object)
    offset_x = map_object.map_offset_x
    offset_y = map_object.map_offset_y
    map_object.grid.each_with_index { |x_obj, x|
      x_obj.each_with_index { |y_obj, y|
        next if x_obj[y].nil?
        self[x + offset_x, y + offset_y] = y_obj
      }
    }
  end

  def generate_starting_area()
    # For now, pretend starting area is just a passage, for simplicity's sake
    configuration = MapGenerator.generate_starting_area_configuration()
    location      = MapGenerator.generate_starting_area_location(self)
    instructions  = configuration["passage"]
    width         = configuration["width"]
    add_passage(instructions: instructions, width: width, x: location[:x], y: location[:y], facing: location[:facing])
  end

  def to_s()
    output = ""
    for y in 0...@grid[0].length do
      for x in 0...@grid.length do
        square = @grid[x][y]
        output.concat(square ? square.to_character : '.')
      end
      output.concat("\n")
    end
    output
  end
end
