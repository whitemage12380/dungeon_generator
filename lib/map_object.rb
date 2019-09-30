require_relative 'map_object_square'
require_relative 'cursor'
require_relative 'connector'

class MapObject
  attr_reader :map, :grid, :cursor, :starting_connector, :map_offset_x, :map_offset_y, :connectors, :doors

  MAX_SIZE = 20

  def initialize(map:, size: MAX_SIZE, starting_connector: nil, offset_x: nil, offset_y: nil)
    @map = map
    @grid = Array.new(size) {Array.new(size)}
    @starting_connector = starting_connector
    @map_offset_x = offset_x
    @map_offset_y = offset_y
    @connectors = []
    @doors = []
  end

  # TODO: Create functions that allow for coordinates OR x, y, right now this is inconsistent

  #def [] (x, y)
  #  @grid[x][y]
  #end

  #def []= (x, y, value)
  #  @grid[x][y] = value
  #end

  def [] (coordinates)
    begin
      @grid[coordinates[:x]][coordinates[:y]]
    rescue Exception => e
      puts "Erroring coordinates: #{coordinates.to_s}"
      puts to_s
      puts map.to_s
      raise
    end
  end

  def []=(coordinates, value)
    begin
      @grid[coordinates[:x]][coordinates[:y]] = value
    rescue Exception => e
      puts "Erroring coordinates: #{coordinates.to_s}"
      puts to_s
      puts map.to_s
      raise
    end
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
    # This line is possibly a stop-gap or a partial solution for passages that can't even begin to draw
    return if not @grid[cursor.pos[:x]] or not @grid[cursor.pos[:x]][cursor.pos[:y]]
    begin
      self[cursor.pos].add_wall(cursor.facing)
      for i in 1...@width do
        cursor.shift!(:right)
        self[cursor.pos].add_wall(cursor.facing)
      end
      cursor.shift!(:left, @width-1)
    rescue Exception => e
      puts "Erroring cursor: #{cursor.to_s}"
      puts to_s
      puts map.to_s
      raise
    end
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
