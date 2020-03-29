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

  def create_connector(cursor = @cursor, width = @width)
    connector = Connector.new(map_object: self,
                                  square: self[cursor.pos],
                                   map_x: cursor.map_x.clone,
                                   map_y: cursor.map_y.clone,
                                  facing: cursor.facing.clone,
                                   width: width)
    @connectors << connector
    puts "Creating connector for map object at (#{connector.map_x}, #{connector.map_y}), facing #{connector.facing}"
    return connector
  end

  def create_door(cursor = @cursor, width = 2)
    door = Door.new(map_object: self,
                        square: self[cursor.pos],
                         map_x: cursor.map_x.clone,
                         map_y: cursor.map_y.clone,
                        facing: cursor.facing.clone,
                         width: width)
    @doors << door
    puts "Creating door for map object at (#{door.map_x}, #{door.map_y}), facing #{door.facing}"
    return door
  end

  def add_connector(connector, connector_offset, cursor: @cursor)
    tmp_cursor = cursor.copy()
    tmp_cursor.shift!(:right, connector_offset)
    self[tmp_cursor.pos].remove_wall(tmp_cursor.facing)
    self[tmp_cursor.pos].add_connector(tmp_cursor.facing, connector)
    for i in 1...connector.width do
      tmp_cursor.shift!(:right)
      self[tmp_cursor.pos].remove_wall(tmp_cursor.facing)
      self[tmp_cursor.pos].add_connector(tmp_cursor.facing, connector)
    end
  end

  def add_door(door, door_offset, cursor: @cursor)
    tmp_cursor = cursor.copy()
    tmp_cursor.shift!(:right, door_offset)
    self[tmp_cursor.pos].add_door(tmp_cursor.facing, door)
    for i in 1...door.width do
      tmp_cursor.shift!(:right)
      self[tmp_cursor.pos].add_door(tmp_cursor.facing, door)
    end
  end

  def draw_forward(distance, cursor: @cursor)
    for i in 1..distance do
      return false if not @map.square_available?(cursor.map_pos_forward)
      cursor.forward!()
      draw_width(cursor: cursor)
    end
    return true
  end

  def draw_width(cursor: @cursor)
    #return false if not @map.square_available?(cursor.map_pos)
    puts "Cursor to draw width: #{cursor}"
    self[cursor.pos] = MapObjectSquare.new({cursor.left => :wall})
    for i in 1...@width do
      cursor.shift!(:right)
      self[cursor.pos] = MapObjectSquare.new()
    end
    self[cursor.pos].add_wall(cursor.right)
    cursor.shift!(:left, @width-1)
  end

  def add_wall_width(cursor: @cursor, width: @width, direction: :right)
    # This line was added earlier but I'm not convinced it's a good idea so I'm commenting it out
    # return if not square_empty?(cursor.pos_forward)
    # This line is possibly a stop-gap or a partial solution for passages that can't even begin to draw
    return if not @grid[cursor.pos[:x]] or not @grid[cursor.pos[:x]][cursor.pos[:y]]
    puts "Adding wall width"
    begin
      self[cursor.pos].add_wall(cursor.facing)
      for i in 1...width do
        cursor.shift!(direction)
        self[cursor.pos].add_wall(cursor.facing)
      end
      cursor.shift!(:left, width-1)
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
