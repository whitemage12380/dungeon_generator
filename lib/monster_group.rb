require_relative 'configuration'
require_relative 'map'

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

  def grouped_monster_lines()
    self.collect { |m| m.name }
        .group_by(&:itself)
        .transform_values(&:count)
        .to_a
        .collect { |m| m[1] == 1 ? m[0] : "#{m[0]} x#{m[1]}" }
  end

  def xp()
    self.sum { |m| m.xp }
  end
end