require_relative 'dungeon_generator_helper'
require_relative 'monster_group'
require_relative 'monster'

class Encounter
  include DungeonGeneratorHelper

  attr_reader :monster_groups, :probability

  def initialize(encounters_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp, probability)
    # Data includes each monster and a range of how many there can be of that monster.
    # To generate the encounter, it must decide whether to generate it simply (randomly between min and max)
    #   or intelligently (aim for a certain xp threshold with randomness and jitter).
    # It could also include an array of multiple encounter, indicating multiple monster groups in the same encounter/chamber
    #   with potential relationships
    # Space available must be considered here, as we can't overcrowd a chamber.
    @monster_groups = Array.new
    @probability = probability
    generate(encounters_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
  end

  def generate(encounters_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
    encounters_data = [encounters_data] unless encounters_data.kind_of? Array
    encounters_data.each { |encounter_data|
      # First add the minimum count of each monster.
      # From there, choose a strategy and execute it.
      # End conditions common to all strategies:
      #   * Monster cannot be added due to chamber space limitations
      #   * Maximum encounter XP reached
      #   * Random chance based on total XP and XP threshold target (as long as minimum encounter XP has been reached)
      #   * All monster count limits have been reached
      encounter_data = {encounter_data => 1} if encounter_data.kind_of? String
      strategy = :chaos
      monsters = minimum_monsters(encounter_data, space_available)
      monsters.concat(case strategy
        when :solo
          random_monsters_strategy_solo(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
        when :chaos
          random_monsters_strategy_chaos(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
        when :order
          random_monsters_strategy_order(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
        when :roll
          random_monsters_strategy_roll(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
        end
        )
      log "Monster group created:"
      log "  Monsters: #{monsters.collect{|m| m.name}.join(", ")}"
      log "  XP: #{total_xp(monsters)}"
      log "  Challenge: #{current_xp_threshold(xp_thresholds, total_xp(monsters)).to_s.pretty}"
      @monster_groups << MonsterGroup.new(monsters: monsters)
    }
  end

  def minimum_monsters(encounter_data, space_available)
    log "Adding minimum monsters"
    monsters = Array.new
    encounter_data.to_a.shuffle.each { |e|
      monster_min(e[1]).times do
        monster = Monster.new(e[0])
        return monsters unless sufficient_space?(monster, space_available)
        add_monster(monsters, monster)
      end
    }
    return monsters
  end

  # Choose a random monster from the encounter and add that monster until an end condition is met
  def random_monsters_strategy_solo(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
    log "Adding monsters with strategy: Solo"
    monster_name, monster_count = encounter_data.to_a.sample
    monsters = Array.new
    while true
      break if monster_limit_reached?(monsters, monster_name, monster_count)
      monster = Monster.new(monster_name)
      new_xp = total_xp(monsters) + monster.xp
      break unless sufficient_space?(monster, space_available)
      break if maximum_xp_reached?(max_xp, new_xp)
      add_monster(monsters, monster)
      break if minimum_xp_reached?(min_xp, new_xp) and finished?(xp_thresholds, xp_threshold_target, new_xp)
    end
    return monsters
  end

  # Randomly add monsters (who have not hit their limit) in the encounter until an end condition is met
  def random_monsters_strategy_chaos(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
    log "Adding monsters with strategy: Chaos"
    monsters = Array.new
    while true
      available_monsters = encounter_data.to_a.reject { |e| monster_limit_reached?(monsters, e[0], e[1]) }
      (log "All monsters have reached their limit" && break) if available_monsters.empty?
      monster_name, monster_count = available_monsters.sample
      monster = Monster.new(monster_name)
      new_xp = total_xp(monsters) + monster.xp
      break unless sufficient_space?(monster, space_available)
      break if maximum_xp_reached?(max_xp, new_xp)
      add_monster(monsters, monster)
      break if minimum_xp_reached?(min_xp, new_xp) and finished?(xp_thresholds, xp_threshold_target, new_xp)
    end
    return monsters
  end

  # Order the monsters. Take random amount of first one below threshold, move on to next if threshold is not yet met, etc
  def random_monsters_strategy_order(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
  end

  def random_monsters_strategy_roll(encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
  end

  def add_monster(monsters, monster)
    monsters << monster
    log "Added monster to encounter: #{monster.name} (Total Space: #{total_monster_squares + total_monster_squares(monsters)}, Total XP: #{total_xp(monsters)})"
  end

  def sufficient_space?(monster, space_available)
    res = (total_monster_squares + monster.squares) <= (space_available * $configuration['encounters']['maximum_chamber_occupancy_percent'])
    log "Insufficient space in chamber for monster: #{monster.name} (squares: #{monster.squares})" unless res
    return res
  end

  def minimum_xp_reached?(min_xp, xp = total_xp)
    res = xp >= min_xp
    log "Not enough XP reached" unless res
    return res
  end

  def maximum_xp_reached?(max_xp, xp = total_xp)
    res = xp >= max_xp
    log "Maximum encounter XP reached" if res
    return res
  end

  def finished?(xp_thresholds, xp_threshold_target, xp = total_xp)
    # 4 below: 0
    # 3 below: 0
    # 2 below: .1
    # 1 below: .2
    # meets: .75
    # 1 above: .9
    # 2 above: .9
    # 3 above: .9
    chance = case xp_threshold_target
    when :easy
      case current_xp_threshold(xp_thresholds, xp) 
      when :trivial;  0.2
      when :easy;     0.75
      when :medium;   0.9
      when :hard;     0.9
      when :deadly;   0.9
      end
    when :medium
      case current_xp_threshold(xp_thresholds, xp) 
      when :trivial;  0.1
      when :easy;     0.2
      when :medium;   0.75
      when :hard;     0.9
      when :deadly;   0.9
      end
    when :hard
      case current_xp_threshold(xp_thresholds, xp) 
      when :trivial;  0
      when :easy;     0.1
      when :medium;   0.2
      when :hard;     0.75
      when :deadly;   0.9
      end
    when :deadly
      case current_xp_threshold(xp_thresholds, xp) 
      when :trivial;  0
      when :easy;     0
      when :medium;   0.1
      when :hard;     0.2
      when :deadly;   0.75
      end
    end
    puts "Chance to finish: #{chance}"
    return (rand() < chance)
  end

  # Do I make a method to pull monsters that have not yet hit max?

  def available_monsters(encounter_data, monsters)
    available_monsters = encounter_data.to_a.reject { |e| monster_limit_reached(monsters, e[0], e[1]) }
    log "All monsters have reached their limit" if available_monsters.empty?
  end

  def monster_limits_reached?(encounter_data, monsters)
    if encounter_data.to_a.all? { |e| monster_limit_reached(monsters, e[0], e[1]) }
      log "Reached all monster limits for encounter"
      return true
    end
    return false
  end

  def monster_limit_reached?(monsters, monster_name, monster_count)
    if monsters.count { |m| m.name == monster_name } >= monster_max(monster_count)
      log "Reached limit for number of monster: #{monster_name.pretty}"
      return true
    end
    return false
  end

  def monster_min(monster_data)
    (monster_data.kind_of? Integer) ? monster_data : monster_data.split("-")[0].to_i
  end

  def monster_max(monster_data)
    (monster_data.kind_of? Integer) ? monster_data : monster_data.split("-")[1].to_i
  end

  def total_xp(monsters = @monster_groups.flatten)
    monsters.sum { |m| (m.kind_of? Monster) ? m.xp : Monster.new(m).xp }
  end

  def total_monster_squares(extra_monsters = [])
    monsters = @monster_groups.flatten + extra_monsters
    monsters.sum { |m| (m.kind_of? Monster) ? m.squares : Monster.new(m).squares }
  end

  def current_xp_threshold(xp_thresholds, xp = total_xp)
    [:deadly, :hard, :medium, :easy].each { |threshold|
      return threshold if xp >= xp_thresholds[threshold]
    }
    return :trivial
  end
end

e = Encounter.new(
  {"goblin" => '1-4', "hobgoblin" => "0-3"},
  {easy: 100, medium: 200, hard: 300, deadly: 400},
  :medium,
  20,
  100,
  200,
  4
  )
puts e.monster_groups.to_s