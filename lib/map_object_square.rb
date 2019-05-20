class MapObjectSquare
  attr_reader :edges, :space

  def initialize(edges = {north: nil, south: nil, east: nil, west: nil})
    @edges = edges
  end

  def add_wall(facing)
    @edges[facing] = :wall
  end

  def remove_wall(facing)
    @edges[facing] = nil if @edges[facing] == :wall
  end

  def to_character()
    return '#'
  end
end
