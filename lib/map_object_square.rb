require_relative 'connector'
require_relative 'door'

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

  def add_connector(facing, connector)
    @edges[facing] = connector
  end

  def remove_connector(facing)
    @edges[facing] = nil if @edges[facing].kind_of? Connector
  end

  def has_connector()
    @edges.each_value { |e| return true if e.kind_of? Connector }
    return false
  end

  def add_door(facing, door)
    @edges[facing] = door
  end

  def remove_door(facing)
    @edges[facing] = nil if @edges[facing].kind_of? Door
  end

  def has_door()
    @edges.each_value { |e| return true if e.kind_of? Door }
    return false
  end

  def rotate()
  end
  def rotate!()
  end

  def to_character()
    return 'C' if has_connector
    return 'D' if has_door
    return '#'
  end
  def to_s()
    output_hash = Hash.new
    @edges.each { |dir, edge|
      case edge
      when Symbol
        output_hash[dir] = edge
      else
        output_hash[dir] = edge.class
      end
    }
    output_hash.to_s
  end
end
