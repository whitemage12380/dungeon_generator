require_relative 'map_object'
require_relative 'chamber_proposal'

class Chamber < MapObject
  attr_reader :length

  def initialize(map:, width:, length:, facing: nil, starting_connector: nil, connector_x: nil, connector_y: nil, entrance_width: nil)
    size = [width, length].max
    super(map: map, size: size, starting_connector: starting_connector)
    if starting_connector
      connector_x = starting_connector.map_x if not connector_x
      connector_y = starting_connector.map_y if not connector_y
      facing = starting_connector.facing if not facing
      entrance_width = starting_connector.width if not entrance_width
    end
    @width = width
    @length = length
    @facing = facing
    proposal = create_proposal(width: width,
                              length: length,
                               map_x: connector_x,
                               map_y: connector_y,
                              facing: facing,
                      entrance_width: entrance_width
    )
    if proposal
      set_attributes_from_proposal(proposal, connector_x, connector_y)
      draw_chamber()
    else
      puts "Failed to propose a chamber"
    end
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

  def side_clearance(cursor, left_distance, right_distance)
    clearance = Hash.new
    tmp_cursor = cursor.copy
    tmp_cursor.turn!(:left)
    clearance[:left] = clear_distance(tmp_cursor, left_distance)
    tmp_cursor.turn!(:back)
    clearance[:right] = clear_distance(tmp_cursor, right_distance)
    return clearance
  end

  def sides_clear?(cursor, left_distance, right_distance)
    clearance = side_clearance(cursor, left_distance, right_distance)
    return false if clearance[:left] != left_distance
    return false if clearance[:right] != right_distance
    return true
  end

  def create_proposal(width:, length:, map_x:, map_y:, facing:, entrance_width:)
    # SETUP
    cursor = Cursor.new(map: map,
                          x: map_x,
                          y: map_y,
                     facing: facing)
    # STEP 1: Check distance from entrance; reduce or fail if shorter than necessary
    puts "Checking how clear it is outward from entrance (length: #{length}, entrance_width: #{entrance_width})"
    puts "Cursor: #{cursor.to_s}"
    length_distance = clear_distance(cursor, length, entrance_width)
    #@length = length_distance
    puts "Length distance: #{length_distance}"
    if length_distance < 2
      puts "Cannot place chamber (not enough space outward from entrance)"
      return
    end
    # STEP 2: Check if room can be placed with no shifting
    #         Assume room is centered from entrance, erring left if perfect centering is impossible
    horizontal_offset = 0
    #width = @width.clone
    width_from_connector = width - entrance_width
    width_from_connector_left = (width_from_connector/2.to_f).ceil - horizontal_offset
    width_from_connector_right = (width_from_connector/2) + entrance_width + horizontal_offset - 1 # "- 1": Don't count current space
    place_as_is = true
    puts "Width left: #{width_from_connector_left}"
    puts "Width right: #{width_from_connector_right}"
    tmp_cursor = cursor.copy
    for length_point in 1..length_distance # Start at base of room (from entrance) and move outward
      puts "Trying length point #{length_point}"
      tmp_cursor.forward!()
      unless sides_clear?(tmp_cursor, width_from_connector_left, width_from_connector_right)
        puts "Sides not clear at point #{length_point}"
        place_as_is = false
        break
      end
    end
    # STEP 2A: Place as-is
    if place_as_is
      proposal = ChamberProposal.new(chamber: self,
          cursor: cursor,
          width_left: width_from_connector_left,
          width: width,
          length: length,
          length_threshold: length,
      )
      return proposal
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
      puts "Chamber was able to be placed as-is"
      return
    end
    # STEP 3: Check each point in length and generate proposals
    chamber_proposals = Array.new
    tmp_cursor = cursor.copy
    for length_point in 1..length_distance
      puts "Checking at length point #{length_point} (of #{length_distance})"
      # STEP 3A: Advance to the next point along the room and get clearance
      tmp_cursor.forward!()
      puts "Cursor: #{tmp_cursor.to_s}"
      clearance = side_clearance(tmp_cursor, (width-entrance_width), (width-1))
      # STEP 3B: Skip from consideration if there are no left/right obstacles
      puts "Skipping from consideration" if clearance[:left] >= width_from_connector_left and clearance[:right] >= width_from_connector_right
      next if clearance[:left] >= width_from_connector_left and clearance[:right] >= width_from_connector_right
      # STEP 3C: Get the number of proposals and first left starting point
      # (width + 1 - pwidth) - (width - min(clear_spaces_from_entrance_right))
      left_proposal_restriction = width - [clearance[:left] + entrance_width, width].min
      right_proposal_restriction = width - [clearance[:right] + entrance_width, width].min
      point_proposals = (width + 1 - entrance_width) - left_proposal_restriction - right_proposal_restriction
      starting_point_offset = clearance[:left]
      #puts "#{width} - [#{clearance[:left] + entrance_width}, #{width}].min"
      puts "#{point_proposals} proposals for this point, with starting offset of #{starting_point_offset}"
      # STEP 3D: Try to build each proposal
      for proposal_num in 0...point_proposals
        proposal = ChamberProposal.new(chamber: self,
          cursor: cursor,
          width_left: clearance[:left] - proposal_num,
          width: width,
          length: length,
          length_threshold: length_point,
          )
        puts "Proposal created: #{proposal.to_h}"
        chamber_proposals << proposal if proposal and not chamber_proposals.collect { |p| p.to_h }.include? proposal.to_h
      end
    end
    chamber_proposals.each { |p| puts p.to_h}
    # To be replaced with a more nuanced selection mechanism at a later time
    chosen_proposal = chamber_proposals.sort_by {|p| p.score }.last
    puts "CHOSEN: #{chosen_proposal.to_h}"
    return chosen_proposal
  end

  def set_attributes_from_proposal(proposal, map_x, map_y)
    @width = proposal.width
    @length = proposal.length
    cursor_pos = initial_cursor_pos(@facing)
    offset_cursor = Cursor.new(map: map,
                                 x: map_x - cursor_pos[:x],
                                 y: map_y - cursor_pos[:y],
                                 facing: @facing)
    offset_cursor.shift!(:left, proposal.width_left)
    @map_offset_x = offset_cursor.x
    @map_offset_y = offset_cursor.y
    puts @map_offset_x
    puts @map_offset_y
    @cursor = Cursor.new(map: map,
                           x: cursor_pos[:x],
                           y: cursor_pos[:y],
                      facing: @facing,
                map_offset_x: @map_offset_x,
                map_offset_y: @map_offset_y)
    puts @cursor.to_s
  end

  def draw_chamber()
    # Supposed to draw back wall first, but not implemented yet
    draw_forward(@length)
    # Supposed to draw back wall, but not implemented yet
    #add_wall_width()
  end

#  def draw_back_wall()
#
#  end


#  def add_wall_width(cursor: @cursor)
#    return if not square_empty?(cursor.pos_forward)
#    self[cursor.pos].add_wall(cursor.facing)
 #   for i in 1...@width do
 #     cursor.shift!(:right)
 #     self[cursor.pos].add_wall(cursor.facing)
 #   end
 #   cursor.shift!(:left, @width-1)
 # end
  ######
  ### CLASS METHODS
  ######

end