require_relative 'dungeon_generator_helper'
require_relative 'encounter'
require_relative 'monster'
puts $LOADED_FEATURES

class EncounterTable
  include DungeonGeneratorHelper

  attr_reader :dominant_inhabitants, :allies, :encounter_list, :encounters_chosen

  def initialize(party_level: $configuration["party_level"], encounter_configuration: encounter_configuration())
    generate(party_level: party_level, encounter_configuration: encounter_configuration())
  end

  def generate(party_level: $configuration["party_level"], encounter_configuration: encounter_configuration())
    case encounter_configuration["encounter_list"]
    when "custom"
      log "Generating custom encounter list"
      @encounter_list = generate_encounter_list()
    when "random"
      raise "Selecting a random encounter list is not yet supported"
    else
      chosen_list_name = encounter_configuration["encounter_list"]
      log "Choosing encounter list: #{chosen_list}"
      encounter_data = YAML.load(File.read("#{DATA_PATH}/encounters/#{chosen_list}.yaml")).values.first
      case encounter_data
      when Hash
        @dominant_inhabitants = encounter_data.fetch("dominant", generate_dominant_inhabitants())
        @allies = encounter_data.fetch("allies", generate_allies())
        @encounter_list = encounter_data["random"]
      when Array
        @encounter_list = encounter_data
      else
        raise "Unexpected format for encounter data! Should be a list of encounters or set of key-value pairs."
      end
    end
  end

  def generate_dominant_inhabitants(dominant_inhabitants_data = encounter_configuration.fetch("dominant_inhabitants", 1))
    # Choose n encounters based on dominant_probability and pull out the monsters involved
    encounters = case dominant_inhabitants_data
    when Array
      dominant_inhabitants_data
    when Integer
      Array.new(dominant_inhabitants_data) { nil }
    when /[0-9]+-[0-9]+/
      Array.new(rand(Range.new(*dominant_inhabitants_data.split("-").collect{|n|n.to_i})))
    when String
      [dominant_inhabitants_data]
    else
      raise "Unexpected format for dominant_inhabitants: #{dominant_inhabitants_data}"
    end
    monsters = encounters.collect { |e|
      if e.nil?
        random_encounter_data = weighted_random(level_appropriate_encounters)["encounter"]
        encounter_monsters = (random_encounter_data.kind_of? Hash) ? random_encounter_data.keys.sample(4) : [random_encounter_data]
      else
        encounter_monsters = [e]
      end
      encounter_monsters.collect { |m| Monster.new(m) }
    }
    puts '???'
    puts monsters.to_s
    return monsters
  end

  def generate_allies(allies_data = encounter_configuration.fetch("allies", 1))
    encounters = case allies_data
    when Array
    when Integer
    when /[0-9]+-[0-9]+/
    when String
    else
    end
  end

  def generate_encounter_list(list_size = $configuration["encounters"]["encounter_list_choices"])
    possible_encounters = level_appropriate_encounters()
    encounter_list = Array.new
    while encounter_list.count <= list_size
      @monster_data = YAML.load(File.read("#{DATA_PATH}/monsters.yaml")) if @monster_data.nil?
      next_encounter = weighted_random(possible_encounters)
      if next_encounter.nil?
        log "Could not find sufficient valid encounters while generating the encounter list (size: #{encounter_list.count})"
        break
      end
      possible_encounters.delete(next_encounter)
      # Notes:
      #   Usually encounters in lists have random counts of each enemy. What we probably need to do
      #   instead is to have a single encounter entry with a single probability then have several possible subchoices.
      #   The alternative is to forsake the idea of randomly generating monster numbers based on an encounter block and
      #   simply add several encounter blocks where needed.
      #   Option 3: Keep what I have but store the entire block as the encounter; figure out the right encounter as the chamber
      #   is being generated. I think that's my favorite, since I need to be dynamic based on chamber size anyway. 
      #   Also, if I want a small handful of not-necessarily-level-appropriate encounters, I'll need to add those separately
      #   from the possible_encounters list.
      next_encounter["encounter"] = [next_encounter["encounter"]] unless next_encounter["encounter"].kind_of? Array
      encounter_list << next_encounter
    end
    log "Encounter List:"
    encounter_list.each { |e|
      log "  Encounter: #{e["encounter"].to_s}"
    }
    return encounter_list.collect { |e| e.select { |k,v| ["encounter", "probability", "xp"].include? k }}
  end

  def random_encounter(chamber, encounter_list = @encounter_list)
    # Allow input to be the chamber object or just the space available
    # Currently all we need is the chamber size
    space_available = (chamber.kind_of? Chamber) ? chamber.size : chamber
    size_category = (space_available > 1600) ? "large" : "small"
    encounter = random_monster_group(space_available, encounter_list)
    if rand() < encounter_configuration["multiple_monster_group_chance"][size_category]
      encounter.add_monster_group(random_monster_group(space_available).monster_groups[0])
    end
    log "Encounter Chosen:"
    log "  #{encounter.monster_groups[0].grouped_monster_lines.join(",")}"
    log "  #{encounter.monster_groups[1].grouped_monster_lines.join(",")}" if encounter.monster_groups.count == 2
    log "  XP: #{encounter.total_xp} - #{encounter.current_xp_threshold(party_xp_thresholds)}"
    @encounters_chosen = Array.new if @encounters_chosen.nil?
    @encounters_chosen << encounter
    return encounter
  end

  def random_monster_group(space_available, max_tries = 3, try = 1)
    log "Attempting to find a suitable monster group, try #{try}"
    monster_group_proposal_count = 3
    xp_threshold_target = random_xp_threshold_target()
    monster_group_proposals = Array.new(monster_group_proposal_count) {
      e = weighted_random(@encounter_list)
      min_xp, max_xp = encounter_xp_values(e["xp"])
      encounter = Encounter.new(e["encounter"], party_xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp, e["probability"])
      probability = e.fetch("probability", 4)
      probability = (probability * 0.75).to_i unless encounter.current_xp_threshold(party_xp_thresholds) == xp_threshold_target
      probability = (probability * 0.75).to_i unless encounter.total_xp <= (party_xp_thresholds[:deadly] * max_xp_threshold_multiplier)
      probability = 0 if encounter.monster_groups.nil? or encounter.monster_groups[0].nil?
      {encounter: encounter, probability: probability}
    }
    puts monster_group_proposals.to_s
    if monster_group_proposals.any? { |mg| mg[:probability] > 0 }
      return weighted_random(monster_group_proposals)[:encounter]
    elsif try < max_tries
      return random_monster_group(space_available, max_tries, try+1)
    else
      raise "Could not create an encounter after #{max_tries} tries. The encounter table is likely poor. In the future, this should be handled better than with an exception."
    end
  end

  def random_xp_threshold_target()
    case encounter_configuration["xp_threshold_strategy"]
    when "random"
      return weighted_random(
        encounter_configuration["xp_threshold_balance"].to_a.collect { |t|
          {threshold: t[0], probability: t[1]}
        }
      )[:threshold].to_sym
    when "balanced"
      raise "Not yet supporting balanced XP thresholds"
      # TODO: Support balanced xp threshold strategy
    else
      raise "Unsupported XP threshold decision strategy: #{encounter_configuration(xp_threshold_strategy)}"
    end
  end

  def level_appropriate_encounters()
    @level_appropriate_encounters = random_encounter_choices.select { |encounter|
      t = party_xp_thresholds()
      # Reject if probability is 0
      # Select if overlap exists between encounter xp range and xp threshold range
      # Select regardless of xp if "special" is true and special encounters are respected in config
      (((encounter["probability"].nil? or encounter["probability"] > 0) and
              encounter_allowed_xp?(encounter, t[:easy], t[:deadly] * max_xp_threshold_multiplier)) or
              (encounter_configuration["special_encounters"] == true and encounter["special"] == true))
    }.collect { |e| {"probability" => 4}.merge(e) } if @level_appropriate_encounters.nil?
    return @level_appropriate_encounters
  end

  def encounter_allowed_xp?(encounter_data, min_xp, max_xp)
    raise "Could not find xp in encounter data: #{encounter_data.to_s}" if encounter_data["xp"].nil?
    encounter_min_xp, encounter_max_xp = encounter_xp_values(encounter_data["xp"])
    return (encounter_min_xp < max_xp and encounter_max_xp > min_xp)
  end

  def encounter_xp_values(xp)
    (xp.kind_of? Integer) ? [xp, xp] : xp.split("-").collect{|x|x.to_i}
  end

  def encounter_configuration()
    if @encounter_configuration.nil?
      @encounter_configuration = $configuration.fetch("encounters", {})
      # Defaults # TODO: This is not a good way to do this, as it defaults only for this class.
      defaults = {
        "dominant_inhabitants" => 1,
        "allies" => 1,
        "encounter_list" => "custom",
        "encounter_list_choices" => 20,
        "maximum_chamber_occupancy_percent" => 0.75,
        "max_xp_threshold_multiplier" => 1.1,
        "random_encounter_choice_list" => "all",
        "xp_threshold_balance" => {
          "easy" => 2,
          "medium" => 3,
          "hard" => 3,
          "deadly" => 2
        },
        "xp_threshold_strategy" => "balanced"
      }
      defaults.each_pair { |conf_name, conf_val|
        @encounter_configuration[conf_name] = conf_val if @encounter_configuration[conf_name].nil?
      }
    end
    return @encounter_configuration
  end

  def random_encounter_choices()
    choices_str = encounter_configuration.fetch("random_encounter_choices", "all")
    YAML.load(File.read("#{DATA_PATH}/encounters/#{choices_str}.yaml"))["encounters"]
  end

  def party_xp_thresholds(party_level = $configuration["party_level"], party_members = $configuration["party_members"])
    @xp_threshold_table = YAML.load(File.read("#{DATA_PATH}/xp_thresholds.yaml"))["xp_thresholds"] if @xp_threshold_table.nil?
    t = @xp_threshold_table[party_level]
    {easy: t[0] * party_members, medium: t[1] * party_members, hard: t[2] * party_members, deadly: t[3] * party_members}
  end

  def max_xp_threshold_multiplier()
    encounter_configuration.fetch("max_xp_threshold_multiplier", 1.1)
  end
end