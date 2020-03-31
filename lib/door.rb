require_relative 'configuration'

require_relative 'map_object'
require_relative 'map_object_square'

class Door < Connector
  attr_reader :material, :state
end
  
