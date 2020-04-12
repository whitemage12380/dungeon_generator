require_relative 'configuration'
require_relative 'map_object_square'
require_relative 'cursor'
require_relative 'connector'

class MapObject
  include DungeonGeneratorHelper
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
    @starting_connector.connect_to(self) if @starting_connector
    map.map_objects << self
  end

  def id()
    map.map_objects.find_index(self)
  end

  def name()
    @name ? @name : "Map Object #{id}"
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
      square(coordinates)
      #@grid[coordinates[:x]][coordinates[:y]]
    rescue Exception => e
      log_error "Erroring coordinates: #{coordinates.to_s}"
      log_error to_s
      puts map.to_s
      raise
    end
  end

  def []=(coordinates, value)
    begin
      @grid[coordinates[:x]][coordinates[:y]] = value
    rescue Exception => e
      log_error "Erroring coordinates: #{coordinates.to_s}"
      log_error to_s
      puts map.to_s
      raise
    end
  end

  def square(x:, y:)
    return nil if @grid[x].nil?
    return @grid[x][y]
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

  def create_connector(cursor = @cursor, width = @width, add_to_connectors = true)
    connector = Connector.new(map_object: self,
                                  square: self[cursor.pos],
                                   map_x: cursor.map_x.clone,
                                   map_y: cursor.map_y.clone,
                                  facing: cursor.facing.clone,
                                   width: width)
    @connectors << connector if add_to_connectors
    log "Creating connector at (#{connector.map_x}, #{connector.map_y}), facing #{connector.facing}"
    return connector
  end

  def create_door(cursor = @cursor, width = 2, add_to_doors = true)
    door = Door.new(map_object: self,
                        square: self[cursor.pos],
                         map_x: cursor.map_x.clone,
                         map_y: cursor.map_y.clone,
                        facing: cursor.facing.clone,
                         width: width)
    @doors << door if add_to_doors
    log "Creating door at (#{door.map_x}, #{door.map_y}), facing #{door.facing}"
    return door
  end

  def add_connector(connector, connector_offset = 0, cursor: @cursor, direction: :right)
    tmp_cursor = cursor.copy()
    tmp_cursor.shift!(direction, connector_offset)
    self[tmp_cursor.pos].remove_wall(tmp_cursor.facing)
    self[tmp_cursor.pos].add_connector(tmp_cursor.facing, connector)
    for i in 1...connector.width do
      tmp_cursor.shift!(direction)
      self[tmp_cursor.pos].remove_wall(tmp_cursor.facing)
      self[tmp_cursor.pos].add_connector(tmp_cursor.facing, connector)
    end
  end

  def add_door(door, door_offset = 0, cursor: @cursor, direction: :right)
    tmp_cursor = cursor.copy()
    tmp_cursor.shift!(direction, door_offset)
    self[tmp_cursor.pos].add_door(tmp_cursor.facing, door)
    for i in 1...door.width do
      tmp_cursor.shift!(direction)
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
    tmp_cursor = cursor.copy()
    #return false if not @map.square_available?(cursor.map_pos)
    debug "Drawing width #{@width} using cursor: #{tmp_cursor}"
    self[tmp_cursor.pos] = MapObjectSquare.new(self, {tmp_cursor.left => :wall})
    for i in 1...@width do
      tmp_cursor.shift!(:right)
      self[tmp_cursor.pos] = MapObjectSquare.new(self)
    end
    self[tmp_cursor.pos].add_wall(tmp_cursor.right)
  end

  def draw_starting_connector(cursor: @cursor)
    tmp_cursor = cursor.copy()
    tmp_cursor.forward!
    tmp_cursor.turn!(:back)
    tmp_cursor.shift!(:right)
    for i in 1..@width do
      tmp_cursor.shift!(:left)
      next if self[tmp_cursor.pos].nil?
      if @map.square(tmp_cursor.map_pos_forward) and @map.square(tmp_cursor.map_pos_forward).edges[tmp_cursor.facing(:back)] == @starting_connector
        if starting_connector.kind_of? Door
          self[tmp_cursor.pos].add_door(tmp_cursor.facing, starting_connector)
        else
          self[tmp_cursor.pos].add_connector(tmp_cursor.facing, starting_connector)
        end
      end
    end
  end

  def add_wall_width(cursor: @cursor, width: @width, direction: :right)
    # This line was added earlier but I'm not convinced it's a good idea so I'm commenting it out
    # return if not square_empty?(cursor.pos_forward)
    # This line is possibly a stop-gap or a partial solution for passages that can't even begin to draw
    return if not @grid[cursor.pos[:x]] or not @grid[cursor.pos[:x]][cursor.pos[:y]]
    debug "Adding #{width}-square-wide wall"
    begin
      self[cursor.pos].add_wall(cursor.facing)
      for i in 1...width do
        cursor.shift!(direction)
        self[cursor.pos].add_wall(cursor.facing)
      end
      cursor.shift!(:left, width-1)
    rescue Exception => e
      log_error "Erroring cursor: #{cursor.to_s}"
      log_error to_s
      puts map.to_s
      raise
    end
  end

  def has_incomplete_connectors?()
    incomplete_connectors = @connectors.select { |c| c.connecting_map_object.nil? }
    incomplete_doors = @doors.select { |d| d.connecting_map_object.nil? }
    if incomplete_connectors.length > 0 or incomplete_doors.length > 0
      log "Incomplete for #{name}: #{incomplete_connectors.length} connectors, #{incomplete_doors.length} doors"
      return true
    end
    log "No incomplete connectors or doors for #{name}"
    return false
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
