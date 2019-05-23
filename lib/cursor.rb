class Cursor
  attr_accessor :x, :y, :facing

  FACINGS = [:north, :east, :south, :west]

  def initialize(map, x, y, facing)
    @x = x
    @y = y
    @facing = facing
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

  def to_s()
    return {x: @x, y: @y, facing: @facing}.to_s
  end
end

