require_relative 'map_object_square'

class MapObject
  @map = []
  @grid = []
  @connectors = []
  @doors = []

  MAX_SIZE = 20

  def initialize(map, size = MAX_SIZE)
    @map = map
    @grid = Array.new(size) {Array.new(size)}
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

  def xlength()
    return @grid.length
  end
  def ylength()
    return @grid[0].length
  end

  def rotate()
    rotated_grid = Array.new
    @grid.transpose.each { |row|
      rotated_grid << row.reverse
    }
    return rotated_grid
  end
  def rotate!()
    @grid = @grid.rotate
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
    #@grid.to_s
  end
end
