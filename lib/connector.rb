require_relative 'map_object'
require_relative 'map_object_square'

class Connector
  attr_reader :map_object, :connecting_map_object, :square

  def initialize(map_object, square = nil)
    @map_object = map_object
    @square = square if square
  end
end
  
