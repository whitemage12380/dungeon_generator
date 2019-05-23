require_relative 'map_object'
require_relative 'map_object_square'

class Door
  attr_reader :map_object, :connecting_map_object, :square, :material, :state

  def initialize(map_object, square)
    @map_object = map_object
    @square = square
  end
  def initialize(map_object)
    @map_object = map_object
  end
end
  
