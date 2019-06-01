class Cursor
  attr_accessor :x, :y, :facing, :map_offset_x, :map_offset_y
  attr_reader :map

  FACINGS = [:north, :east, :south, :west]
  TURNS = [:forward, :right, :back, :left]

  def initialize(map:, x:, y:, facing:, map_offset_x: nil, map_offset_y: nil)
    @map = map
    @x = x
    @y = y
    @facing = facing
    @map_offset_x = map_offset_x
    @map_offset_y = map_offset_y
  end

  def facing(turn = :forward)
    facing_i = FACINGS.index(@facing)
    case turn
    when :forward
      return @facing
    when :left
      facing_i -= 1
    when :right
      facing_i += 1
    when :back
      facing_i += 2
    when :north, :east, :south, :west
      return turn
    end
    facing_i += FACINGS.length if facing_i < 0
    facing_i -= FACINGS.length if facing_i >= FACINGS.length
    return FACINGS[facing_i]
  end

  def facing_to_turn(new_facing)
    facing_i = FACINGS.index(@facing)
    new_facing_i = FACINGS.index(new_facing)
    diff = new_facing_i - facing_i
    case diff
    when 0
      return :forward
    when 1, 3
      return :right
    when -2, 2
      return :back
    when -1, -3
      return :left
    end
  end

  def left()
    facing(:left)
  end
  def right()
    facing(:right)
  end
  def back()
    facing(:right)
  end

  def pos()
    {x: @x, y: @y}
  end

  def pos_forward(distance = 1)
    case @facing
    when :north
      return {x: @x.clone, y: @y.clone - distance}
    when :east
      return {x: @x.clone + distance, y: @y.clone}
    when :south
      return {x: @x.clone, y: @y.clone + distance}
    when :west
      return {x: @x.clone - distance, y: @y.clone}
    end
  end

  def map_x()
    @x + @map_offset_x
  end
  def map_y()
    @y + @map_offset_y
  end
  def map_pos()
    {x: map_x, y: map_y}
  end
  def map_pos_forward(distance = 1)
    pos = pos_forward(distance)
    return {x: pos[:x] + @map_offset_x, y: pos[:y] + @map_offset_y}
  end

  def forward!(distance = 1)
    case @facing
    when :north
      @y -= distance
    when :east
      @x += distance
    when :south
      @y += distance
    when :west
      @x -= distance
    end
  end

  def turn!(turn)
    @facing = facing(turn)
  end

  def back!(distance = 1)
    turn!(:back)
    forward!(distance)
    turn!(:back)
  end

  def shift!(turn, distance = 1)
    turn!(turn)
    forward!(distance)
    case turn
    when :left
      turn!(:right)
    when :right
      turn!(:left)
    end
  end

  def copy()
    return Cursor.new(map: @map,
                        x: @x.clone,
                        y: @y.clone,
                   facing: @facing.clone,
             map_offset_x: @map_offset_x.clone,
             map_offset_y: @map_offset_y.clone)
  end

  def to_s()
    return {x: @x, y: @y, facing: @facing}.to_s
  end
end

