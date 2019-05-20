require_relative 'map_object'
require_relative 'cursor'

class Passage < MapObject

  def initialize(map, width, instructions)
    super(map)
    @width = width
    @cursor = Cursor.new(map, 0, (ylength / 2) - ((width-1) / 2), :east)

    #pen = {x: 0, y: (ylength / 2), facing: :east}
    
    #pen[:y] -= ((width-1) / 2)
    #puts pen
    puts @cursor.to_s
    self[@cursor.pos] = MapObjectSquare.new
    #self[pen] = MapObjectSquare.new

    instructions.each { |instruction|
      processPassageInstruction(instruction)
    }
    puts self.to_s
  end

  def processPassageInstruction(instruction)
    case instruction
    when /^FORWARD [1-9]\d*$/
      distance = (instruction.scan(/\d+/).first.to_i) / 5
      draw_forward(distance)
    when "CONNECTOR"
    end
  end

  def draw_forward(distance)
    draw_width()
    for i in 1..distance do
      @cursor.forward!()
      draw_width()
    end
  end

  def draw_width()
    return if not @map.square_available?(@cursor.pos)
    self[@cursor.pos] = MapObjectSquare.new({@cursor.left => :wall})
    for i in 1...@width do
      @cursor.shift!(:right)
      self[@cursor.pos] = MapObjectSquare.new()
    end
    self[@cursor.pos].add_wall(@cursor.right)
    @cursor.shift!(:left, @width-1)

  end
end
