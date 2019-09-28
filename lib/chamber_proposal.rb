require_relative 'configuration'
require_relative 'chamber'

class ChamberProposal
  attr_reader :chamber, :width_left, :width, :length, :alignment_count
  # length_threshold is a special integer that the proposal algorithm uses to determine
  # how to handle obstacles (reduce width and continue vs cut off length and stop)

  def initialize(chamber:, cursor:, width_left:, width:, length:, length_threshold:)
    @chamber = chamber
    p = build_proposal(cursor, width_left.clone, width.clone, length.clone, length_threshold.clone)
    @width_left = p[:width_left]
    @width = p[:width]
    @length = p[:length]
    @alignment_count = p[:aligns]
  end

  def build_proposal(starting_cursor, width_left, width, length, length_threshold)
    # Added left_distance so that the cursor can start at the entrance
    # So that it's easy to figure out in some cases whether to shorten the left or right side
    aligns = 0
    # Start drawing the room out
    cursor = starting_cursor.copy
    width_right = width - width_left - 1
    for length_point in 1..length
      cursor.forward!()
      # Alignment test
      align_clearance = @chamber.side_clearance(cursor, width_left+1, width_right+1) # Add 1 to test for alignments
      aligns += 1 if align_clearance[:left] < width_left+1
      aligns += 1 if align_clearance[:right] < width_right+1
      # Get actual clearance
      clearance = @chamber.side_clearance(cursor, width_left, width_right)
      puts "  Clearances for point #{length_point}: (#{clearance[:left]}, #{clearance[:right]})"
      if length_point < length_threshold
        # If there is an obstacle at this length, shrink width as necessary and continue
        if clearance[:left] < width_left
          puts "  Obstacle found at point #{length_point} (left). Reducing width by #{width_left} - #{clearance[:left]} = #{width_left - clearance[:left]}"
          width -= (width_left - clearance[:left])
          width_left = clearance[:left]
        end
        if clearance[:right] < width_right
          puts "  Obstacle found at point #{length_point} (right). Reducing width by #{width_right} - #{clearance[:right]} = #{width_right - clearance[:right]}"
          width -= (width_right - clearance[:right])
          width_right = clearance[:right]
        end
      else
        # If there is an obstacle at this length, shrink length to right before it and finish
        if clearance[:left] < width_left-1 or clearance[:right] < width_right-1
          length = length_point - 1
          cursor.back!()
          break
        end
      end
    end
    aligns += forward_aligns(cursor, width_left, width)
    return {
      width_left: width_left,
      width: width,
      length: length,
      aligns: aligns
    }
  end

  def forward_aligns(starting_cursor, width_left, width)
    aligns = 0
    cursor = starting_cursor.copy
    cursor.shift!(:left, width_left)
    for distance in 0..width do
      aligns += 1 unless chamber.map.square_available?(cursor.pos_forward())
      cursor.shift!(:right)
    end
    return aligns
  end

  def score()
    align_score = alignment_count * $configuration["weights"]["align_weight"]
    area_score = width * length * $configuration["weights"]["area_weight"]
    align_score + area_score
  end

  def to_h()
    return {width: width, length: length, width_left: width_left, alignment_count: alignment_count, score: score}
  end
end