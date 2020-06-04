require_relative 'configuration'

class MonsterGroup < Array
  include DungeonGeneratorHelper

  attr_reader :motivation

  def initialize(monsters: nil, table: "nightmare_gate", category: nil, motivation: nil)
    puts "category: #{category}"
    if monsters.nil?
      monsters = MapGenerator.random_monsters(table, category)
    end
    self.concat(monsters)
    if $configuration['generate_monster_motivation'] == true and motivation.nil?
      @motivation = MapGenerator.random_yaml_element("monster_motivations")['description']
    else
      @motivation = motivation
    end
  end
end