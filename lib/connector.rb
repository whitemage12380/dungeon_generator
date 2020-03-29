require_relative 'map_object'
require_relative 'map_object_square'

class Connector
  attr_reader :map_object, :connecting_map_object, :square, :facing, :width, :map_x, :map_y

  def initialize(map_object:, square: nil, facing: nil, width: nil, map_x: nil, map_y: nil)
    @map_object = map_object
    @square = square if square
    @facing = facing if facing
    @width = width
    @map_x = map_x if map_x
    @map_y = map_y if map_y
  end

  def connect_to(map_object)
    @connecting_map_object = map_object
  end

  def to_s()
    output = "Connector: "
    output += "Connects from a map object. " if map_object
    output += "Connects to a map object. " if connecting_map_object
    output += "facing: #{facing}, width: #{width}, coordinates: (#{map_x}, #{map_y})."
    return output
  end
end
  
