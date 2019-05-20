require_relative 'map_object'

class Map
  @grid = []

  MAX_SIZE = 500

  def initialize(size = MAX_SIZE)
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
end
