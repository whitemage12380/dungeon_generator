require_relative 'configuration'
require_relative 'map_object'
require_relative 'map_object_square'

class Connector
  include DungeonGeneratorHelper
  attr_reader :map_object, :connecting_map_object, :square, :facing, :width, :map_x, :map_y

  def initialize(map_object:, square: nil, facing: nil, width: nil, map_x: nil, map_y: nil)
    @map_object = map_object
    @square = square if square
    @facing = facing if facing
    @width = width
    @map_x = map_x if map_x
    @map_y = map_y if map_y
  end

  def type()
    case self
    when Door
      return "door"
    else
      return "connector"
    end
  end

  def exit_string(starting_connector = false)
    if type == "connector"
      exit_type = "Exit"
    else
      exit_type = type.capitalize()
    end
    if starting_connector
      connecting_to = @map_object.name
      facing_string = opposite_facing(facing)
    else
      connecting_to = @connecting_map_object ? @connecting_map_object.name : "nothing!"
      facing_string = @facing
    end
    puts "map_x: #{map_x}"
    puts "map_y: #{map_y}"
    return "#{exit_type} at (#{map_x}, #{map_y}) facing #{facing_string} to #{connecting_to}"
  end

  def x()
    map_x - map_object.map_offset_x
  end

  def y()
    map_y - map_object.map_offset_y
  end

  def pos()
    {x: x, y: y}
  end

  def map_pos()
    {x: map_x, y: map_y}
  end

  def new_cursor()
    return Cursor.new(map: map_object.map,
                        x: x,
                        y: y,
                   facing: facing,
             map_offset_x: map_object.map_offset_x,
             map_offset_y: map_object.map_offset_y,
      )
  end

  def connect_to(map_object)
    @connecting_map_object = map_object
  end

  def disconnect()
    @connecting_map_object = nil
  end

  # Returns true if there is a map object in front of the connector that can be connected to
  def can_connect_forward?()
    unless connecting_map_object.nil?
      debug "Cannot connect forward because connector is already connected"
      return false
    end
    map = @map_object.map
    cursor = Cursor.new(map: map,
                          x: map_x,
                          y: map_y,
                     facing: facing)
    cursor.forward!()
    cursor.turn!(:back)
    (@width-1).times do |p|
      square = map.square(cursor.pos)
      if square.nil?                                        # Squares must exist
        debug "Cannot connect forward because square #{p} is either solid rock or the end of the map"
        return false
      end
      unless square.edges[cursor.facing] == :wall           # Squares must have a wall between them and the connector
        debug "Cannot connect forward because square #{p} does not have a wall against the connector"
        return false
      end
      unless square.edges[cursor.left].nil?                 # Squares must not have anything between themselves
        debug "Cannot connect forward because square #{p} has a wall or connector between it and square #{p+1}"
        return false
      end
      cursor.shift!(:left)
    end
    square = map.square(cursor.pos)
    if square.nil?                                        # Last square must exist
      debug "Cannot connect forward because square #{@width} is either solid rock or the end of the map"
      return false
    end
    unless square.edges[cursor.facing] == :wall           # Last square must have a wall between it and the connector
      debug "Cannot connect forward because square #{@width} does not have a wall against the connector"
      return false
    end
    return true
  end

  def connect_forward()
    raise "Cannot connect forward!" unless can_connect_forward?
    log "Connecting forward to existing object"
    map = @map_object.map
    cursor = Cursor.new(map: map,
                          x: map_x,
                          y: map_y,
                     facing: facing)
    cursor.forward!()
    cursor.turn!(:back)
    cursor.shift!(:left, @width-1)
    connecting_map_object = map.square(cursor.pos).map_object
    log "Connecting to #{connecting_map_object.name}"
    connect_to(connecting_map_object)
    # Have other map object create connector and connect back to our map object
    # Map coordinates are easy, but how do I figure out the correct map object coordinates?
    # Are there special issues around potentially having to "redraw" a map object from the map's perspective?
    # A simple redraw would draw any additions or changes to squares, but not erasures.
    other_cursor = Cursor.new(map: map,
                                x: cursor.x - connecting_map_object.map_offset_x,
                                y: cursor.y - connecting_map_object.map_offset_y,
                                facing: cursor.facing,
                                map_offset_x: connecting_map_object.map_offset_x,
                                map_offset_y: connecting_map_object.map_offset_y)
    log "Creating reciprocal connection back to #{@map_object.name}"
    if self.kind_of? Door
      other_connector = connecting_map_object.create_door(other_cursor, @width)
    else
      other_connector = connecting_map_object.create_connector(other_cursor, @width)
    end
    connecting_map_object.add_connector(other_connector, cursor: other_cursor)
    other_connector.connect_to(@map_object)
  end

  def to_s()
    output = "Connector: "
    output += "Connects from #{map_object.name} " if map_object
    output += "Connects to #{connecting_map_object.name}. " if connecting_map_object
    output += "facing: #{facing}, width: #{width}, coordinates: (#{map_x}, #{map_y})."
    return output
  end
end
  
