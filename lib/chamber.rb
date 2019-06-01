require_relative 'map_object'

class Chamber < MapObject
  attr_reader :length

  def initialize(map:, width:, length:, facing: :east, starting_connector: nil, connector_x: nil, connector_y: nil, instructions: nil)
    size = [width, length].max
    super(map: map, size: size, starting_connector: starting_connector)
    @width = width
    @length = length

    # TODO: Before getting cursor_pos we must figure out clearance
    starting_x = connector_x
    starting_y = connector_y
    starting_x += 1 if starting_x == -1
    starting_x -= 1 if starting_x == xlength
    starting_y += 1 if starting_y == -1
    starting_y -= 1 if starting_y == ylength


    cursor_pos = initial_cursor_pos(facing)
    @map_offset_x = connector_x - cursor_pos[:x]
    @map_offset_y = connector_y - cursor_pos[:y]
    @cursor = Cursor.new(map: map,
                           x: cursor_pos[:x],
                           y: cursor_pos[:y],
                      facing: facing,
                map_offset_x: @map_offset_x,
                map_offset_y: @map_offset_y)
    instructions.each { |instruction|
      if not process_passage_instruction(instruction)
        # We hit a map edge or another map object; wall it off and be done
        add_wall_width()
        break
      end
    }
  end

  def clearance(x, y, object_facing)
    clearance = Hash.new
    [:north, :east, :south, :west].each { |facing|
      clearance[facing] = nil if facing == object_facing
      cursor = Cursor.new(map: map, x: x, y: y, facing: object_facing, map_offset_x: 0, map_offset_y: 0)
      c = 0
      turn = cursor.facing_to_turn(facing)
      case turn
      when :forward
        max_distance = @length
        # check_width = ??? How much horizontally are we checking here?
      when :left
        max_distance = @width - @starting_connector.width
        check_width = @length
        cursor.forward!()
        cursor.turn!(:left)
      when :right
        max_distance = @width - 1
        check_width = @length
        cursor.forward!()
        cursor.turn!(:right)
      when :back
        clearance[facing] = nil
        next
      end
      # Now we do the loop until we hit something or reach maximum distance, checking our entire length/width as appropriate

      # Max distance depends on width or length, depending on which facing it is compared to the object facing
      # If looking width-wise, should be done at first point within the boundary
      # If looking length-wise, should be done at true starting point, prior to object boundary
    }
  end
end