require_relative 'map_object'

class Map
  attr_accessor :grid, :objects

  MAX_SIZE = 500

  def initialize(size = MAX_SIZE)
    @grid = Array.new(size) {Array.new(size)}
    @objects = Array.new
  end

  def [] (x, y)
    @grid[x][y]
  end

  def []= (x, y, value)
    @grid[x][y] = value
  end

  def [] (coordinates)
    @grid[coordinates[:x]][coordinates[:y]]
  end

  def []=(coordinates, value)
    @grid[coordinates[:x]][coordinates[:y]] = value
  end

  def square(x:, y:)
    @grid[x][y]
  end

  def square_available?(x:, y:)
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

  def add_passage(connector: nil, width: nil, x: nil, y: nil, facing: nil, instructions: nil)
    # If given a connector (which outside of dev/testing will always be true),
    # it can figure out x, y, and facing and it can randomize width based on the connector as well.
    # The passage can then do the rest of the work.
    # The passage itself should figure out its instructions if not given.
    @objects << Passage.new(map: self, width: width, facing: facing, instructions: instructions)

  end

  def draw_map_object(map_object)
  end
end
