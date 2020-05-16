require_relative 'configuration'
require_relative 'map_generator'
require_relative 'map_object'
require_relative 'passage'
require_relative 'chamber'
require_relative 'stairs'

class Map
  include DungeonGeneratorHelper
  extend DungeonGeneratorHelper
  attr_accessor :grid, :map_objects, :file, :theme

  MAX_SIZE = 500

  def initialize(size = MAX_SIZE, theme: nil)
    @grid = Array.new(size) {Array.new(size)}
    @map_objects = Array.new
    @theme = theme
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
    return nil if x < 0 or y < 0
    return @grid[x][y]
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

  def stairs()
    map_objects.select { |mo| mo.kind_of? Stairs }
  end

  def add_passage(passage: nil, connector: nil, width: nil, x: nil, y: nil, facing: nil, instructions: nil)
    if passage.nil?
      if connector
        passage = Passage.new(map: self, starting_connector: connector, instructions: instructions)
      else
        passage = Passage.new(map: self, width: width, facing: facing, connector_x: x, connector_y: y, instructions: instructions)
      end
    end
    return add_map_object(passage, connector)
  end

  def add_chamber(chamber: nil, connector: nil, width: nil, length: nil, x: nil, y: nil, facing: nil, entrance_width: nil)
    if chamber.nil?
      if connector
        chamber = Chamber.new(map: self, starting_connector: connector, width: width, length: length)
      else
        chamber = Chamber.new(map: self, width: width, length: length, facing: facing, connector_x: x, connector_y: y, entrance_width: entrance_width)
      end
    end
    return add_map_object(chamber, connector)
  end

  def add_stairs(stairs: nil, connector: nil, width: 2, length: 2, x: nil, y: nil, facing: nil, entrance_width: nil)
    if stairs.nil?
      if connector
        stairs = Stairs.new(map: self, starting_connector: connector, width: width, length: length)
      else
        stairs = Stairs.new(map: self, width: width, length: length, facing: facing, connector_x: x, connector_y: y, entrance_width: entrance_width)
      end
    end
    return add_map_object(stairs, connector)
  end

  def add_map_object(map_object, connector = nil)
    if map_object.success? and draw_map_object(map_object)
      @map_objects << map_object
      return map_object
    elsif map_object.success? and connector
      log_important "Adding #{map_object.name} to map was unsuccessful because drawing on the map failed"
      connecting_map_object = connector.map_object
      connector.disconnect()
      connecting_map_object.blocked_connector_behavior(connector)
      return nil
    else
      return nil
    end
  end

  def can_draw_map_object?(map_object)
    offset_x = map_object.map_offset_x
    offset_y = map_object.map_offset_y
    map_object.grid.each_with_index { |x_obj, x|
      x_obj.each_with_index { |y_obj, y|
        next if x_obj[y].nil?
        return false unless self[x + offset_x, y + offset_y].nil?
      }
    }
    return true
  end

  def draw_map_object(map_object)
    return false unless can_draw_map_object?(map_object)
    offset_x = map_object.map_offset_x
    offset_y = map_object.map_offset_y
    map_object.grid.each_with_index { |x_obj, x|
      x_obj.each_with_index { |y_obj, y|
        next if x_obj[y].nil?
        self[x + offset_x, y + offset_y] = y_obj
      }
    }
    map_object.drawn
    return true
  end

  def generate_starting_area()
    # For now, pretend starting area is just a passage, for simplicity's sake
    configuration = MapGenerator.generate_starting_area_configuration()
    location      = MapGenerator.generate_starting_area_location(self)
    #instructions  = configuration["passage"]
    width         = configuration["width"]
    #add_passage(instructions: instructions, width: width, x: location[:x], y: location[:y], facing: location[:facing])
    case configuration["type"]
    when "chamber"
      length = configuration["length"]
      map_object = add_chamber(width: width, length: length, x: location[:x], y: location[:y], facing: location[:facing])
      locations_used = Array.new()
      configuration["exits"].each { |exit|
        exit_type = exit["type"]
        exit_facing = exit["facing"]
        if exit_facing == "unique"
          exit_facing = MapGenerator.random_facing(locations_used)
          locations_used << exit_facing.clone()
        end
        map_object.add_exit({location: exit_facing, type: exit_type})
      }
    when "passage"
      instructions  = configuration["passage"]
      map_object = add_passage(instructions: instructions, width: width, x: location[:x], y: location[:y], facing: location[:facing])
    end
    map_object.description = "Starting area. #{configuration["description"]}."
    return map_object
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

  def save(filename = 'latest', filepath = $configuration['saved_map_directory'])
    if filename =~ /^\/.*\.yaml$/
      fullpath = filename
    else
      filepath = File.expand_path("#{File.dirname(__FILE__)}/../#{filepath}") unless filepath[0] == '/'
      fullpath = "#{filepath}/#{filename}.yaml"
    end
    log "Saving map to file: #{fullpath}"
    File.open(fullpath, "w") do |f|
      YAML::dump(self, f)
    end
  end

  def self.load(filename, filepath = $configuration['saved_map_directory'])
    if filename =~ /^\/.*\.yaml$/
      fullpath = filename
    else
      filepath = File.expand_path("#{File.dirname(__FILE__)}/../#{filepath}") unless filepath[0] == '/'
      fullpath = "#{filepath}/#{filename}.yaml"
    end
    log "Loading map from file: #{fullpath}"
    map = nil
    File.open(fullpath, "r") do |f|
      map = YAML::load(f)
    end
    return map
  end
end
