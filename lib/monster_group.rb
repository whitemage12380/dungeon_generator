require_relative 'configuration'
require_relative 'map'

class MonsterGroup < Array
  include DungeonGeneratorHelper

  attr_reader :motivation

  def initialize(monsters: nil, table: nil, category: nil, motivation: nil)
    if monsters.nil?
      log_error "No monsters provided to new monster group. Assuming empty group."
      monsters = []
    end
    self.concat(monsters)
    if $configuration['generate_monster_motivation'] == true and motivation.nil?
      @motivation = random_yaml_element("monster_motivations")['description']
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

  def to_s(include_motivation: false)
    grouped_monster_lines.join(", ") + (include_motivation and @motivation ? ". Motivation: #{@motivation}" : "")
  end
end