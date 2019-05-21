require_relative 'map_object'
require_relative 'map_object_square'

class Connector
  #attr_accessor :x, :y, :width
  attr_reader :map_object, :connecting_map_object, :square

  #def initialize(x, y, width)
    #@x = x
    #@y = y
    #@width = width
    # This is going to be tough. Map objects need to be able to be rotated. Adding separate objects with their own coordinates make it very difficult to rotate.
  #end
  def initialize(map_object, square)
    @map_object = map_object
    @square = square
  end
  def initialize(map_object)
    @map_object = map_object
  end
end
  
