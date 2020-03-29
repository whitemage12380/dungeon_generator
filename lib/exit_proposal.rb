

class ExitProposal
  attr_reader :width, :alignment_count, :cursor, :distance_from_left

  BASE_WEIGHT = 3
  ALIGN_WEIGHT = 10
  CENTERED_WEIGHT = 10

  def initialize(map:, chamber:, cursor:, chamber_width:, width:, distance_from_left:)
    @map = map
    @chamber = chamber
    @cursor = cursor.copy
    @chamber_width = chamber_width
    @width = width
    @distance_from_left = distance_from_left
    @cursor.shift!(:right, distance_from_left)
  end

  def exit_allowed?(map: @map, chamber: @chamber, cursor: @cursor, width: @width)
    tmp_cursor = cursor.copy
    square = map.square(cursor.map_pos)
    puts cursor.to_s
    for width_point in 1..width
      return false if chamber.square_empty?(cursor.pos)
      return false unless square.edges[cursor.facing] == :wall
      return false unless map.square_available?(tmp_cursor.map_pos_forward(1))
      tmp_cursor.shift!(:right)
    end
    return true
  end

# Check for walls on the square to the left and right of the exit in the row/column the exit points to
  def aligns(map: @map, cursor: @cursor, width: @width)
    return 0 unless exit_allowed?
    tmp_cursor = cursor.copy
    tmp_cursor.forward!()
    tmp_cursor.shift!(:left)
    left_square = map.square(cursor.map_pos)
    tmp_cursor.shift!(:right, width + 1)
    right_square = map.square(cursor.map_pos)
    alignments = 0
    alignments += 1 if left_square.edges[cursor.facing(:right)] == :wall
    alignments += 1 if right_square.edges[cursor.facing(:left)] == :wall
    return alignments
  end

# Centered means dead-center if possible, one of two possible central-ish positions otherwise
  def centered?(chamber_width = @chamber_width, width = @width, distance_from_left = @distance_from_left)
    if chamber_width % 2 == 0
      return true if distance_from_left == (chamber_width / 2) - (width.to_f / 2).floor or
                     distance_from_left == (chamber_width / 2) - (width.to_f / 2).ceil
    elsif width % 2 == 0
      return true if distance_from_left == (chamber_width.to_f / 2).floor - (width / 2) or
                     distance_from_left == (chamber_width.to_f / 2).ceil - (width / 2)
    else
      return true if distance_from_left == (chamber_width / 2) - (width / 2)
    end
    return false
  end

  def score()
    base_score = BASE_WEIGHT
    align_score = aligns() * ALIGN_WEIGHT
    centered_score = centered?() ? CENTERED_WEIGHT : 0
    return align_score + centered_score + base_score
  end

  def to_connector()
    return Connector.new(
      map_object: @chamber,
      square: @map.square(@cursor.map_pos),
      facing: @cursor.facing,
      width: @width,
      map_x: @cursor.map_pos[:x],
      map_y: @cursor.map_pos[:y]
    )
  end

  def to_h()
    return {width: width, cursor_pos: cursor.pos, distance_from_left: distance_from_left, alignment_count: aligns, centered: centered?, score: score}
  end
end