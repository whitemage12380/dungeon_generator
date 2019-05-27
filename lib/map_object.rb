require_relative 'map_object_square'
require_relative 'connector'

class MapObject
  attr_reader :map, :grid, :map_offset_x, :map_offset_y, :connectors, :doors

  MAX_SIZE = 20

  def initialize(map, size = MAX_SIZE, offset_x = nil, offset_y = nil)
    @map = map
    @grid = Array.new(size) {Array.new(size)}
    @map_offset_x = offset_x
    @map_offset_y = offset_y
    @connectors = []
    @doors = []
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

  def square_empty?(coordinates)
    return self[coordinates].nil?
  end

  def rotate!(turn = :left)
    # TODO: Rotate each individual square so the walls are correct
    case turn
    when :left
      rotation_count = 1
    when :back
      rotation_count = 2
    when :right
      rotation_count = 3
    when Integer
      rotation_count = turn
    end
    rotation_count.times do
      rotated_grid = Array.new
      @grid.transpose.each { |row|
        rotated_grid << row.reverse
      }
      @grid = rotated_grid
    end
  end

  def compact!()
    # Remove empty columns
    (@grid.length - 1).downto(0) { |x|
      @grid.slice!(x) if not @grid[x].any?
    }
    # Remove empty rows
    (@grid[0].length - 1).downto(0) { |y|
      # Slice the y for each x IF there are not any x's for which the y is not nil
      @grid.each {|x| x.slice!(y)} if not @grid.select {|x| not x[y].nil?}.any?
    }
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
