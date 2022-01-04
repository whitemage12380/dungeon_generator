require_relative 'dungeon_generator_helper'
require_relative 'monster_group'
require_relative 'monster'

class Encounter
  include DungeonGeneratorHelper

  attr_reader :monster_groups, :probability, :relationship, :xp_threshold_target, :special

  def initialize(encounters_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp, probability, special = false)
    @monster_groups = Array.new
    @probability = probability
    @special = special
    @xp_threshold_target = xp_threshold_target
    generate(encounters_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp, special)
  end

  ######### Encounter Generation
  ####

  def generate(encounters_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp, special = false)
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
      strategy = :roll if @special
      log "Creating monster encounter (Target XP Threshold: #{xp_threshold_target.to_s.capitalize}, Space Available: #{space_available})"
      monsters = minimum_monsters(encounter_data, space_available)
      space_remaining = space_available - total_monster_squares(monsters)
      monsters = (case strategy
        when :solo
          random_monsters_strategy_solo(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_remaining, min_xp, max_xp)
        when :chaos
          random_monsters_strategy_chaos(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_remaining, min_xp, max_xp)
        when :order
          random_monsters_strategy_order(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_remaining, min_xp, max_xp)
        when :roll
          random_monsters_strategy_roll(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_remaining, min_xp, max_xp)
        else
          log_error "Unknown strategy: #{strategy}. Skipping further monster placement."
        end
      ) unless monsters.count > 0 and finished?(xp_thresholds, xp_threshold_target, total_xp(monsters))
      monster_group = MonsterGroup.new(monsters: monsters)
      log "Monster group created:"
      log "  Monsters: #{monster_group.grouped_monster_lines.join(",")}"
      log "  XP: #{total_xp(monsters)}"
      log "  Challenge: #{current_xp_threshold(xp_thresholds, total_xp(monsters)).to_s.pretty}"
      @monster_groups << monster_group
      raise "More than 2 monster groups in an encounter are not supported" if @monster_groups.count > 2
    }
    generate_monster_group_relationship()
  end

  def generate_monster_group_relationship()
    return if @monster_groups.count == 1
    @relationship = random_yaml_element("monster_relationships")["description"]
    return @relationship
  end

  # Add a monster group generated in another encounter and create a relationship

  def add_monster_group(monster_group, relationship = nil)
    raise "Only 2 monster groups are currently supported in an encounter" if @monster_groups.count == 2
    @monster_groups << monster_group
    if relationship.nil?
      generate_monster_group_relationship()
    else
      @relationship = relationship
    end
  end

  ######### Adding Monsters
  ####

  def minimum_monsters(encounter_data, space_available)
    debug "Adding minimum monsters"
    monsters = Array.new
    encounter_data.to_a.shuffle.each { |e|
      monster_min(e[1]).times do
        monster = Monster.new(e[0])
        return monsters unless sufficient_space?(monsters, monster, space_available)
        add_monster(monsters, monster)
      end
    }
    return monsters
  end

  # Choose a random monster from the encounter and add that monster until an end condition is met
  def random_monsters_strategy_solo(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
    log "Adding monsters with strategy: Solo"
    monster_name, monster_count = encounter_data.to_a.sample
    monsters = Array.new if monsters.nil?
    while true
      break if monster_limit_reached?(monsters, monster_name, monster_count)
      monster = Monster.new(monster_name)
      new_xp = total_xp(monsters) + monster.xp
      break unless sufficient_space?(monsters, monster, space_available)
      break if maximum_xp_reached?(max_xp, new_xp)
      add_monster(monsters, monster)
      break if minimum_xp_reached?(min_xp, new_xp) and finished?(xp_thresholds, xp_threshold_target, new_xp)
    end
    return monsters
  end

  # Randomly add monsters (who have not hit their limit) in the encounter until an end condition is met
  def random_monsters_strategy_chaos(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
    log "Adding monsters with strategy: Chaos"
    monsters = Array.new if monsters.nil?
    while true
      monster_list = available_monsters(encounter_data, monsters, xp_thresholds)
      break if monster_list.empty?
      monster_name, monster_count = monster_list.sample
      monster = Monster.new(monster_name)
      new_xp = total_xp(monsters) + monster.xp
      break unless sufficient_space?(monsters, monster, space_available)
      break if maximum_xp_reached?(max_xp, new_xp)
      add_monster(monsters, monster)
      break if minimum_xp_reached?(min_xp, new_xp) and finished?(xp_thresholds, xp_threshold_target, new_xp)
    end
    return monsters
  end

  # Order the monsters. Take random amount of first one below threshold, move on to next if threshold is not yet met, etc
  def random_monsters_strategy_order(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
  end

  # For each monster type (in a random order) take a fully-random count between min and max, stopping until done or no space left
  def random_monsters_strategy_roll(monsters, encounter_data, xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp)
    log "Adding monsters with strategy: Roll"
    monsters = Array.new if monsters.nil?
    encounter_data.to_a.shuffle.to_h.each_pair { |monster_name, monster_count|
      low, high = (monster_count.kind_of? Integer) ? monster_count : monster_count.split("-").collect(&:to_i)
      high = low if high.nil?
      roll = rand(Range.new(low, high)) - low # Minimum monsters already added, so reduce by minimum
      roll.times do
        monster = Monster.new(monster_name)
        break unless sufficient_space?(monsters, monster, space_available)
        add_monster(monsters, monster)
      end
    }
    return monsters
  end

  def add_monster(monsters, monster)
    monsters << monster
    log "Added monster to encounter: #{monster.name} (Total Space for strategy: #{total_monster_squares + total_monster_squares(monsters)}, Total XP: #{total_xp(monsters)})"
  end

  ######### Encounter-building Helpers
  ####

  def sufficient_space?(monsters, monster, space_available)
    res = (total_monster_squares(monsters + [monster])) <= (space_available * $configuration['encounters']['maximum_chamber_occupancy_percent'])
    log "Insufficient space in chamber for monster: #{monster.name} (squares: #{monster.squares})" unless res
    return res
  end

  def minimum_xp_reached?(min_xp, xp = total_xp)
    res = xp >= min_xp
    log "Not enough XP reached" unless res
    return res
  end

  def maximum_xp_reached?(max_xp, xp = total_xp)
    res = xp > max_xp
    log "Maximum encounter XP reached" if res
    return res
  end

  def finished?(xp_thresholds, xp_threshold_target, xp = total_xp)
    chance = chance_to_finish(xp_thresholds, xp_threshold_target, xp)
    if rand() < chance
      log "Finishing monster placement (chance to finish was #{(chance * 100).to_i}%)"
      return true
    else
      log "Continuing to place monsters (chance to finish was #{(chance * 100).to_i}%)"
      return false
    end
  end

  def chance_to_finish(xp_thresholds, xp_threshold_target, xp = total_xp)
    # 4 below: 0
    # 3 below: 0
    # 2 below: .1
    # 1 below: .2
    # meets: .75
    # 1 above: .9
    # 2 above: .9
    # 3 above: .9
    case xp_threshold_target
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
  end

  def available_monsters(encounter_data, monsters, xp_thresholds)
    available_monsters = encounter_data.to_a.reject { |e| monster_limit_reached?(monsters, e[0], e[1]) }
                                            .reject { |e| Monster.new(e[0]).xp > max_monster_xp(xp_thresholds)}
    log "There are no more available monsters in XP range" if available_monsters.empty?
    return available_monsters
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

  def max_monster_xp(xp_thresholds)
    xp_thresholds[:deadly] * $configuration["encounters"]["max_xp_threshold_multiplier"]
  end

  ######### Generally Useful Helpers
  ####

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

  def to_s_lines()
    if monster_groups.size == 1
      [monster_groups.first.to_s(include_motivation: true)]
    else
      [
        "Group 1: #{monster_groups[0].to_s(include_motivation: true)}",
        "Group 2: #{monster_groups[1].to_s(include_motivation: true)}",
        "Relationship: #{@relationship}"
      ]
    end
  end

  def to_s()
    to_s_lines.join("\n")
  end
end