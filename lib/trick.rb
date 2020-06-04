require_relative 'configuration'

class Trick
  include DungeonGeneratorHelper

  attr_accessor :object, :effect

  def initialize(object: nil, effect: nil)
    object = MapGenerator.random_yaml_element("trick_objects") if object.nil?
    effect = MapGenerator.random_yaml_element("trick_effects")["description"] if effect.nil?
    @object = object
    @effect = effect
  end

  def to_h()
    {object: @object, effect: @effect}
  end
end