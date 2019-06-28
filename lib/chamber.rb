require_relative 'map_object'

class Chamber < MapObject
  attr_reader :length

  def initialize(map:, width:, length:, facing: nil, starting_connector: nil, connector_x: nil, connector_y: nil, entrance_width: nil)
    size = [width, length].max
    super(map: map, size: size, starting_connector: starting_connector)
    @width = width
    @length = length
    if starting_connector
      connector_x = starting_connector.map_x if not connector_x
      connector_y = starting_connector.map_y if not connector_y
      facing = starting_connector.facing if not facing
      entrance_width = starting_connector.width if not entrance_width
    end
    position!(connector_x, connector_y, facing, entrance_width)
    return


    # Everything below here not to be kept
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

  def initial_cursor_pos(facing)
    case facing
    when :north
      x = 0
      y = @length
    when :east
      x = -1
      y = 0
    when :south
      x = @width
      y = -1
    when :west
      x = @length
      y = @width
    end
    return {x: x, y: y}
  end

  def clear_distance(cursor, max_distance, width = 1)
    tmp_cursor = cursor.copy
    distances = Array.new
    for width_point in 0...width do
      for distance in 1..max_distance do
        unless @map.square_available?(tmp_cursor.pos_forward(distance))
          distances[width_point] = distance - 1
          break
        end
      end
      distances[width_point] = max_distance if not distances[width_point]
      tmp_cursor.shift!(:right)
    end
    return distances.min
  end

  def sides_clear?(cursor, left_distance, right_distance)
    tmp_cursor = cursor.copy
    tmp_cursor.turn!(:left)
    return false if clear_distance(tmp_cursor, left_distance) != left_distance
    tmp_cursor.turn!(:back)
    return false if clear_distance(tmp_cursor, right_distance) != right_distance
    return true
  end

  def position!(map_x, map_y, facing, entrance_width)
    cursor = Cursor.new(map: map,
                          x: map_x,
                          y: map_y,
                     facing: facing)
    length_distance = clear_distance(cursor, @length, entrance_width)
    puts "Length distance: #{length_distance}"
    # Check if room can be placed with no shifting
    # Assume room is centered from entrance, erring left if perfect centering is impossible
    horizontal_offset = 0
    width = @width.clone
    width_from_connector = width - entrance_width
    width_from_connector_left = (width_from_connector/2.to_f).ceil - horizontal_offset
    width_from_connector_right = (width_from_connector/2) + entrance_width + horizontal_offset
    place_as_is = true
    puts "Width left: #{width_from_connector_left}"
    puts "Width right: #{width_from_connector_right}"
    for length_point in 1..length_distance
      puts "Trying length point #{length_point}"
      cursor.forward!()
      unless sides_clear?(cursor, width_from_connector_left, width_from_connector_right)
        place_as_is = false
        break
      end
    end
    if place_as_is
      # Width and length unchanged. Have to record beginning-left point, or some other way to indicate how to draw the room.
      # Best bet: Set object's cursor to beginning-left point.
      cursor_pos = initial_cursor_pos(facing)
      offset_cursor = Cursor.new(map: map,
                            x: map_x - cursor_pos[:x],
                            y: map_y - cursor_pos[:y],
                       facing: facing)
      offset_cursor.shift!(:left, width_from_connector_left)
      @map_offset_x = offset_cursor.x
      @map_offset_y = offset_cursor.y
      puts @map_offset_x
      puts @map_offset_y
      @cursor = Cursor.new(map: map,
                             x: cursor_pos[:x],
                             y: cursor_pos[:y],
                        facing: facing,
                  map_offset_x: @map_offset_x,
                  map_offset_y: @map_offset_y)
      puts @cursor.to_s
      # I also need to indicate where the connector/door is, because the drawing needs to understand that.
      # That said, it technically already knows because it has the starting connector's map x and y coordinates.
    end
    chamber_proposals = Array.new

  end
end