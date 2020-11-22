require_relative 'configuration'

require_relative 'map_object'
require_relative 'map_object_square'

class Door < Connector
  attr_reader :style, :state

  def initialize(map_object:, square: nil, facing: nil, width: nil, map_x: nil, map_y: nil, door_type_data: nil)
    super(map_object: map_object, square: square, facing: facing, width: width, map_x: map_x, map_y: map_y)
    generate_door(door_type_data)
  end

  def generate_door(door_type_data)
    door_type_data = random_yaml_element('door_types') if door_type_data.nil?
    @style = door_type_data['style']
    @state = door_type_data['state']
  end

  def door_description()
    output = @style.nil? ? "Door" : @style.capitalize()
    output += " (#{state})" unless @state.nil?
    return output
  end
end
  
