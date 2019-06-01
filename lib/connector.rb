require_relative 'map_object'
require_relative 'map_object_square'

class Connector
  attr_reader :map_object, :connecting_map_object, :square, :facing, :width, :map_x, :map_y

  def initialize(map_object:, square: nil, facing: nil, width: nil, map_x: nil, map_y: nil)
    @map_object = map_object
    @facing = facing if facing
    @square = square if square
    @width = width
    @map_x = map_x if map_x
    @map_y = map_y if map_y
  end
end
  
