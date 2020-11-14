require_relative 'configuration'

class Item
  include DungeonGeneratorHelper
  attr_reader :name, :worth

  def initialize(name, worth = nil)
    @name = name
    @worth = worth
  end

  def to_s()
    worth.nil? ? name : "#{name} (#{worth} gp)"
  end
end