require_relative 'configuration'
require_relative 'map_object'
require_relative 'chamber_proposal'
require_relative 'exit_proposal'
require_relative 'trap'
require_relative 'trick'

class Chamber < MapObject
  attr_reader :width, :length

  def initialize(map:, width:, length:, facing: nil, starting_connector: nil, connector_x: nil, connector_y: nil, entrance_width: nil,
                 name: nil, description: nil, contents: nil)
    size = [width, length].max
    super(map: map, size: size, starting_connector: starting_connector)
    log "Creating #{id_str} with intended dimensions: #{width}x#{length}"
    if starting_connector
      connector_x = starting_connector.map_x if not connector_x
      connector_y = starting_connector.map_y if not connector_y
      facing = starting_connector.facing if not facing
      entrance_width = starting_connector.width if not entrance_width
    end
    @width = width
    @length = length
    @facing = facing
    if $configuration["generate_chamber_purpose"] == true and name.nil? and description.nil?
      @name, @description = MapGenerator.generate_chamber_name_and_description(map)
    end
    if $configuration["generate_chamber_contents"] == true and contents.nil?
      #@contents = MapGenerator.generate_chamber_contents(map)
      generate_contents()
    else
      @contents = contents ? contents : Hash.new()
    end
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
      log "Created #{id_str}"
      @status = :success
    else
      log "#{id_str}: Failed to propose a chamber"
      starting_connector.disconnect()
      starting_connector.map_object.blocked_connector_behavior(starting_connector)
      @status = :failure
    end
  end

  def id()
    map.chambers.find_index(self)
  end

  # Position coordinate hash of Northwest corner
  def abs_map_pos()
    cursor = Cursor.new(map: map,
                          x: initial_cursor_pos[:x],
                          y: initial_cursor_pos[:y],
               map_offset_x: @map_offset_x,
               map_offset_y: @map_offset_y,
                     facing: @facing
    )
    cursor.forward!()
    while square(cursor.pos).nil?
      puts cursor.pos
      cursor.shift!(:right)
      return nil unless cursor.pos_valid?
    end
    case @facing
    when :north
      cursor.forward!(length-1)
    when :south
      cursor.shift!(:right, width-1)
    when :east
      # Already there
    when :west
      cursor.shift!(:right, width-1)
      cursor.forward!(length-1)
    end
    return cursor.map_pos
  end

  # Distance from West to East
  def abs_width()
    case @facing
    when :north, :south; @width
    when :east, :west;   @length
    end
  end

  # Distance from North to South
  def abs_length()
    case @facing
    when :north, :south; @length
    when :east, :west;   @width
    end
  end

  def initial_cursor_pos(facing = @facing)
    # If facing is not along the same axis as the chamber facing, reverse length/width.
    width = @width
    length = @length
    case @facing
    when :north, :south
      if [:east, :west].include? facing
        width = @length
        length = @width
      end
    when :east, :west
      if [:north, :north].include? facing
        width = @length
        length = @width
      end
    end
    # Return a position that, from the given facing, is at the back-most left-most square of the chamber.
    case facing
    when :north
      x = 0
      y = length
    when :east
      x = -1
      y = 0
    when :south
      x = width - 1
      y = -1
    when :west
      x = length
      y = width - 1
    end
    return {x: x, y: y}
  end

  def clear_distance(cursor, max_distance, width = 1)
    width = 1 if width.nil? or width < 1
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

  def default_proposal(cursor:, width_from_connector_left:, width_from_connector_right:, width:, length:)
    tmp_cursor = cursor.copy
    for length_point in 1..length # Start at base of room (from entrance) and move outward
      debug "Trying length point #{length_point}"
      tmp_cursor.forward!()
      unless sides_clear?(tmp_cursor, width_from_connector_left, width_from_connector_right)
        debug "Sides not clear at point #{length_point}"
        return nil
      end
    end
    log "Placing as-is."
    proposal = ChamberProposal.new(chamber: self,
        cursor: cursor,
        width_left: width_from_connector_left,
        width: width,
        length: length,
        length_threshold: length,
    )
    debug "Proposal: #{proposal.to_h}"
    return proposal
  end

  def create_proposal(width:, length:, map_x:, map_y:, facing:, entrance_width:)
    # SETUP: Cursor, length, width-related calculations
    cursor = Cursor.new(map: map,
                          x: map_x,
                          y: map_y,
                     facing: facing)
    debug "Checking how clear it is outward from entrance (length: #{length}, entrance_width: #{entrance_width})"
    debug "Cursor: #{cursor.to_s}"
    length = clear_distance(cursor, length, entrance_width)
    debug "Length after initial truncate: #{length}"
    if length < 2
      log "Cannot place chamber (not enough space outward from entrance)"
      return
    end
    horizontal_offset = 0
    entrance_width = 1 if entrance_width.nil?
    width_from_connector = width - entrance_width
    width_from_connector_left = (width_from_connector/2.to_f).floor.to_i - horizontal_offset
    width_from_connector_right = (width_from_connector/2.to_f).ceil.to_i + entrance_width + horizontal_offset - 1 # "- 1": Don't count current space
    debug "Width left: #{width_from_connector_left}"
    debug "Width right: #{width_from_connector_right}"
    # STEP 1: Use default layout proposal if possible
    p = default_proposal( cursor: cursor,
       width_from_connector_left: width_from_connector_left,
      width_from_connector_right: width_from_connector_right,
                           width: width,
                          length: length,
      )
    return p if p
    # STEP 2: Check each point in length and generate proposals
    chamber_proposals = create_chamber_proposals(
      cursor: cursor,
      length: length,
      width:  width,
      entrance_width: entrance_width,
      width_from_connector_left: width_from_connector_left,
      width_from_connector_right: width_from_connector_right,
    )
    # STEP 3: Choose a proposal
    # To be replaced with a more nuanced selection mechanism at a later time
    chosen_proposal = chamber_proposals.sort_by {|p| p.score }.last
    log "Chose chamber proposal: #{chosen_proposal.to_h}"
    return chosen_proposal
  end

  # TODO: Make this method work when there is no entrance (it's the starting chamber).
  def create_chamber_proposals(cursor:, length:, width:, entrance_width:, width_from_connector_left:, width_from_connector_right:)
    chamber_proposals = Array.new
    tmp_cursor = cursor.copy
    for length_point in 1..length
      debug "Checking at length point #{length_point} (of #{length})"
      # STEP 2A: Advance to the next point along the room and get clearance
      tmp_cursor.forward!()
      debug "  Cursor: #{tmp_cursor.to_s}"
      clearance = side_clearance(tmp_cursor, (width-entrance_width), (width-1))
      # STEP 2B: Skip from consideration if there are no left/right obstacles
      debug "  Skipping from consideration" if clearance[:left] >= width_from_connector_left and clearance[:right] >= width_from_connector_right
      next if clearance[:left] >= width_from_connector_left and clearance[:right] >= width_from_connector_right
      # STEP 2C: Get the number of proposals and first left starting point
      # (width + 1 - pwidth) - (width - min(clear_spaces_from_entrance_right))
      left_proposal_restriction = width - [clearance[:left] + entrance_width, width].min
      right_proposal_restriction = width - [clearance[:right] + entrance_width, width].min
      point_proposals = (width + 1 - entrance_width) - left_proposal_restriction - right_proposal_restriction
      starting_point_offset = clearance[:left]
      debug "  #{point_proposals} proposals for this point, with starting offset of #{starting_point_offset}"
      # STEP 2D: Try to build each proposal
      for proposal_num in 0...point_proposals
        proposal = ChamberProposal.new(chamber: self,
          cursor: cursor,
          width_left: clearance[:left] - proposal_num,
          width: width,
          length: length,
          length_threshold: length_point,
          )
        debug "  Proposal created: #{proposal.to_h}"
        chamber_proposals << proposal if proposal and not chamber_proposals.collect { |p| p.to_h }.include? proposal.to_h
      end
    end
    debug "Chamber Proposals:"
    chamber_proposals.each { |p| debug "  #{p.to_h}"}
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
    @cursor = Cursor.new(map: map,
                           x: cursor_pos[:x],
                           y: cursor_pos[:y],
                      facing: @facing,
                map_offset_x: @map_offset_x,
                map_offset_y: @map_offset_y)
    debug @cursor.to_s
  end

  def draw_chamber()
    initial_cursor = @cursor.copy()
    draw_forward(@length)
    draw_near_wall(cursor: initial_cursor)
    draw_far_wall()
    draw_starting_connector(cursor: initial_cursor)
  end

  def draw_near_wall(cursor: @cursor)
    tmp_cursor = cursor.copy()
    tmp_cursor.forward!
    tmp_cursor.turn!(:back)
    add_wall_width(cursor: tmp_cursor, direction: :left)
  end

  def draw_far_wall(cursor: @cursor)
    tmp_cursor = cursor.copy()
    add_wall_width(cursor: tmp_cursor)
  end

  def draw_exit(cursor, exit_proposal)
    # Currently assumes cursor is at the left edge of the room we want to draw the exit on
    add_connector(exit_proposal.to_connector, exit_proposal.distance_from_left, cursor: cursor) # Currently ignores doors; should be add_door for doors
  end

  def add_exits(exits = MapGenerator.random_chamber_exits(size_category))
    exits.each { |exit|
      add_exit(exit)
    }
  end

  def add_exit(exit)
    location = exit[:location].to_sym
    facing = @cursor.facing(location)
    cursor_pos = initial_cursor_pos(facing)
    cursor = Cursor.new( map: map,
                           x: cursor_pos[:x],
                           y: cursor_pos[:y],
                      facing: facing,
                map_offset_x: @map_offset_x,
                map_offset_y: @map_offset_y)
    # STEP 1: Walk cursor up to the opposite edge of the chamber
    # distance needs to be either width or length depending on whether exit location is forward/back or left/right
    if location == :forward or location == :back
      forward_distance = @length
      side_distance = @width
    else
      forward_distance = @width
      side_distance = @length
    end
    cursor.forward!(forward_distance)
    # STEP 2: Create exit proposals and choose a favorite
    exit_proposals = create_exit_proposals(cursor: cursor, wall_width: side_distance) # Let exit_width default to 2 for now
    if exit_proposals.empty?
      log "#{id_str}: Failed to create any successful proposals for exit: #{exit}"
      log "#{id_str}: Skipping exit."
      return
    end
    chosen_proposal = MapGenerator.weighted_random(exit_proposals.collect { |p| {proposal: p, "probability" => p.score} })[:proposal]
    log "#{id_str}: Chose exit proposal: #{chosen_proposal.to_h}"
    # STEP 3: Attach the exit (door, connector or passage)
    case exit[:type]
    when "passage"
      connector = chosen_proposal.to_connector()
      add_connector(connector, chosen_proposal.distance_from_left, cursor: cursor)
      connector.connect_to(Passage.new(map: @map, starting_connector: connector, instructions: exit[:passage]))
    when "connector"
      connector = chosen_proposal.to_connector()
      add_connector(connector, chosen_proposal.distance_from_left, cursor: cursor)
    when "door"
      door = chosen_proposal.to_door()
      add_door(door, chosen_proposal.distance_from_left, cursor: cursor)
    end
  end

  def create_exit_proposals(cursor:, wall_width:, exit_width: 2)
    exit_proposals = Array.new
    for width_point in 0..(wall_width - exit_width)
      log "Creating proposal at width_point #{width_point} (#{cursor.pos})"
      proposal = ExitProposal.new(cursor: cursor, map: @map, chamber: self, wall_width: wall_width, width: exit_width, distance_from_left: width_point)
      log "#{id_str}: Proposal: #{proposal.to_h}"
      log "#{id_str}: Checking whether exit is allowed at cursor: #{proposal.cursor.to_s}"
      if proposal.exit_allowed?
        exit_proposals << proposal
      else
        log "#{id_str}: Exit proposal not allowed."
      end
    end
    debug "Proposal list: #{exit_proposals.collect{|p| p.to_h }}"
    return exit_proposals
  end

  def size()
    @length * @width
  end

  def size_category()
    if size > 1600
      return "large"
    else
      return "normal"
    end
  end

  def generate_contents()
    contents_yaml = random_yaml_element("chamber_contents")
    contents = {
      description: contents_yaml["description"],
      hazards: [],
      monsters: [],
      obstacles: [],
      traps: [],
      treasure: [],
      tricks: [],
    }
    return contents if contents_yaml["contents"].nil?
    contents_yaml["contents"].each { |c|
      case c
      when /^monster/
        category = c.split("_").last
        #puts "category: #{category}"
        #contents[:monsters] << MonsterGroup.new(category: category)
        case category
        when "dominant"
          log "Dominant creatures not yet supported; using random encounter instead"
          encounter = @map.encounter_table.random_encounter(size)
        when "ally"
          log "Dominant creatures not yet supported; using random encounter instead"
          encounter = @map.encounter_table.random_encounter(size)
        when "random"
          encounter = @map.encounter_table.random_encounter(size)
        else
          raise "Unrecognized monster category: #{category}"
        end
        contents[:monsters] << encounter
      when "hazard"
        contents[:hazards] << random_yaml_element("hazards")["description"]
      when "obstacle"
        contents[:obstacles] << random_yaml_element("obstacles")["description"]
      when "trap"
        contents[:traps] << Trap.new()
      when "trick"
        contents[:tricks] << Trick.new()
      when "treasure"
        contents[:treasure] << c
      else
        raise "Unknown chamber content type: #{c}"
      end
    }
    @contents = contents
    return contents
  end


  ######
  ### CLASS METHODS
  ######

end