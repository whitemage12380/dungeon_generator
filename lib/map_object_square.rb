require_relative 'configuration'
require_relative 'connector'
require_relative 'door'

class MapObjectSquare
  include DungeonGeneratorHelper
  attr_reader :map_object, :edges, :space

  def initialize(map_object = nil, edges = {north: nil, south: nil, east: nil, west: nil})
    @map_object = map_object
    @edges = edges
  end

  def add_wall(facing)
    @edges[facing] = :wall
  end

  def remove_wall(facing)
    @edges[facing] = nil if @edges[facing] == :wall
  end

  def has_wall()
    @edges.each_value { |e| return true if e == :wall}
    return false
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
    return 'D' if has_door
    return 'C' if has_connector
    return '^' if has_wall
    return '#'
  end
  def to_s()
    output_hash = Hash.new
    if @map_object
      output_hash[:map_object] = @map_object.name
    end
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
