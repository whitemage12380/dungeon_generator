require_relative 'configuration'
require_relative 'map_object_square'
require_relative 'cursor'
require_relative 'connector'

class MapObject
  include DungeonGeneratorHelper

  attr_accessor :description, :contents
  attr_reader :map, :grid, :cursor, :starting_connector, :map_offset_x, :map_offset_y, :connectors, :doors, :status

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
    @description = "This #{type.downcase} does not have a description."
  end

  def id()
    map.map_objects.find_index(self)
  end

  def id_str()
    "#{type.capitalize} #{id}"
  end

  def name()
    @name ? @name : id_str
  end

  def name=(val)
    @name = val.empty? ? nil : val
  end

  def label()
    name == id_str ? name : "#{id_str} - #{name}"
  end

  def type()
    case self
    when Chamber
      return "chamber"
    when Passage
      return "passage"
    when Stairs
      return "staircase"
    else
      return "map object"
    end
  end

  def starting_connector_type()
    case @starting_connector
    when Door
      return "door"
    when Connector
      return "connector"
    else
      return nil
    end
  end

  def success?
    status == :success
  end

  def drawn
    @drawn = true
  end

  def drawn?
    @drawn == true
  end

  def all_connectors()
    @connectors + @doors
  end

  def exits()
    @connectors + @doors
  end

  def connector_list(connector)
    case connector
    when Door
      connector_list = @doors
    when Connector
      connector_list = @connectors
    end
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

  def each_square()
    return to_enum(:each) unless block_given?
    xlength.times { |x|
      ylength.times { |y|
        yield(square(x: x, y: y), x, y)
      }
    }
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
    puts "Creating connector cursor: #{cursor}"
    connector = Connector.new(map_object: self,
                                  square: self[cursor.pos],
                                   map_x: cursor.map_x.clone,
                                   map_y: cursor.map_y.clone,
                                  facing: cursor.facing.clone,
                                   width: width)
    log "Creating connector at (#{connector.map_x}, #{connector.map_y}), facing #{connector.facing}"
    return connector
  end

  def create_door(cursor = @cursor, width = 2)
    door = Door.new(map_object: self,
                        square: self[cursor.pos],
                         map_x: cursor.map_x.clone,
                         map_y: cursor.map_y.clone,
                        facing: cursor.facing.clone,
                         width: width)
    log "Creating door at (#{door.map_x}, #{door.map_y}), facing #{door.facing}"
    return door
  end

  def add_connector(connector, connector_offset = 0, cursor: @cursor, direction: :right)
    connector_list = connector_list(connector)
    connector_list << connector unless connector_list.include?(connector)
    tmp_cursor = cursor.copy()
    tmp_cursor.shift!(direction, connector_offset)
    log "#{name}: Adding connector - cursor: #{tmp_cursor.to_s}"
    self[tmp_cursor.pos].add_connector(tmp_cursor.facing, connector)
    for i in 1...connector.width do
      tmp_cursor.shift!(direction)
      log "#{name}: Adding connector - cursor: #{tmp_cursor.to_s}"
      self[tmp_cursor.pos].add_connector(tmp_cursor.facing, connector)
    end
    return connector
  end

  alias add_door add_connector

  def draw_forward(distance, cursor: @cursor, width: @width)
    for i in 1..distance do
      return false unless width_available?(cursor: cursor, width: width)
      log "#{name}: OK to draw forward at #{cursor.map_pos_forward}, #{cursor.facing}"
      cursor.forward!()
      draw_width(cursor: cursor, width: width)
    end
    return true
  end

  def width_available?(cursor: @cursor, distance: 1, width: @width)
    tmp_cursor = cursor.copy()
    for i in 1..width do
      return false unless @map.square_available?(tmp_cursor.map_pos_forward)
      tmp_cursor.shift!(:right)
    end
    return true
  end

  def draw_width(cursor: @cursor, width: @width)
    tmp_cursor = cursor.copy()
    #return false if not @map.square_available?(cursor.map_pos)
    debug "Drawing width #{width} using cursor: #{tmp_cursor}"
    self[tmp_cursor.pos] = MapObjectSquare.new(self, {tmp_cursor.left => :wall})
    for i in 1...width do
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
    log "Adding #{width}-square-wide wall at #{cursor.map_pos.to_s}"
    begin
      tmp_cursor = cursor.copy()
      self[tmp_cursor.pos].add_wall(tmp_cursor.facing)
      for i in 1...width do
        tmp_cursor.shift!(direction)
        self[tmp_cursor.pos].add_wall(tmp_cursor.facing)
      end
    rescue Exception => e
      log_error "Erroring cursor: #{cursor.to_s}"
      log_error to_s
      puts map.to_s
      raise
    end
  end

  def remove_wall_width(cursor: @cursor, width: @width, direction: :right)
    tmp_cursor = cursor.copy()
    self[tmp_cursor.pos].remove_wall(tmp_cursor.facing)
    for i in 1...width do
      tmp_cursor.shift!(direction)
      self[tmp_cursor.pos].remove_wall(tmp_cursor.facing)
    end
  end

  def remove_connector(connector)
    connector_list = connector_list(connector)
    return false unless connector_list.include?(connector)
    connector_list.delete(connector)
    cursor = connector.new_cursor()
    add_wall_width(cursor: cursor, width: connector.width)
    return true
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

  def blocked_connector_behavior(connector, type = nil)
    cursor = connector.new_cursor()
    type = connector.type if type.nil?
    if connector.can_connect_forward?()
      # blocked_passage_behavior can be set via configuration
      blocked_passage_behavior = $configuration['blocked_passage_behavior'] ? $configuration['blocked_passage_behavior'] : 'random'
      # blocked_passage_behavior is randomly set based on blocked_passage_behavior.yaml if random (default)
      if blocked_passage_behavior == 'random'
        blocked_passage_behavior = MapGenerator.random_yaml_element('blocked_passage_behavior')['type']
      end
      # blocked_passage_behavior is set to whatever kind of connector we're given if that connector was already added to the map object
      if blocked_passage_behavior != "wall" and all_connectors.include?(connector)
        blocked_passage_behavior = connector.type
      end
      log "Able to connect blocked #{type} forward, chosen behavior is: #{blocked_passage_behavior}"
      case blocked_passage_behavior
      when 'wall'
        log "Choosing to wall off blocked #{type}"
        unless remove_connector(connector)
          add_wall_width(cursor: cursor, width: connector.width)
        end
      when 'connector'
        log "Connecting #{name} to forward map object"
        add_connector(connector, cursor: cursor) unless @connectors.include?(connector)
        connector.connect_forward()
      when 'door'
        if @doors.include?(connector)
          log "Connecting door to forward map object"
          connector.connect_forward()
        else
          log "Creating a door from #{name} to forward map object"
          remove_connector(connector)
          door = create_door(cursor, connector.width)
          add_door(door, cursor: cursor)
          door.connect_forward()
        end
      end
    else
      log "Unable to connect blocked #{type} forward; walling it off"
      remove_connector(connector) || add_wall_width(cursor: cursor, width: connector.width)
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
