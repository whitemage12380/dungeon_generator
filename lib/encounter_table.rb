require_relative 'dungeon_generator_helper'
require_relative 'encounter'
require_relative 'monster'

class EncounterTable
  include DungeonGeneratorHelper

  attr_reader :dominant_inhabitants, :allies, :random_encounters, :encounters_chosen

  def initialize(party_level: $configuration["party_level"], encounter_configuration: encounter_configuration())
    generate(party_level: party_level, encounter_configuration: encounter_configuration())
  end

  ######### Encounter Table Generation
  ####

  def generate(party_level: $configuration["party_level"], encounter_configuration: encounter_configuration())
    case encounter_configuration["encounter_list"]
    when "custom"
      log "Generating custom encounter list"
      @dominant_inhabitants = generate_dominant_inhabitants()
      @allies = generate_allies()
      @random_encounters = generate_random_encounters()
    when "random"
      raise "Selecting a random encounter list is not yet supported"
    else
      chosen_list_name = encounter_configuration["encounter_list"]
      log "Choosing encounter list: #{chosen_list}"
      encounter_data = YAML.load(File.read("#{DATA_PATH}/encounters/#{chosen_list}.yaml")).values.first
      case encounter_data
      when Hash
        # TODO: Below logic needs revisiting
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
    return nil unless encounter_configuration["enable_dominant_inhabitants"]
    possible_encounters = level_appropriate_encounters(dominant_inhabitant_choices())
    list_size = random_count(dominant_inhabitants_data)
    log "Generating #{list_size} dominant inhabitants"
    return generate_encounter_list(possible_encounters, list_size)
  end

  def generate_allies(allies_data = encounter_configuration.fetch("allies", 1))
    return nil unless encounter_configuration["enable_allies"]
    possible_encounters = level_appropriate_encounters(ally_choices())
    list_size = random_count(allies_data)
    log "Generating #{list_size} allies/pets"
    return generate_encounter_list(possible_encounters, list_size)
  end

  def generate_random_encounters()
    log "Generating random encounters"
    generate_encounter_list(level_appropriate_encounters)
  end

  def generate_encounter_list(possible_encounters, list_size = $configuration["encounters"]["encounter_list_choices"])
    encounter_list = Array.new
    while encounter_list.count < list_size
      @monster_data = YAML.load(File.read("#{DATA_PATH}/monsters.yaml")) if @monster_data.nil?
      next_encounter = weighted_random(possible_encounters)
      if next_encounter.nil?
        log "Could not find sufficient valid encounters while generating the encounter list (size: #{encounter_list.count})"
        break
      end
      possible_encounters.delete(next_encounter)
      next_encounter["encounter"] = [next_encounter["encounter"]] unless next_encounter["encounter"].kind_of? Array
      encounter_list << next_encounter
    end
    log "Encounter List:"
    encounter_list.each { |e|
      log "  Encounter: #{e["encounter"].to_s}"
    }
    return encounter_list.collect { |e| e.select { |k,v| ["encounter", "probability", "xp", "special"].include? k }}
  end

  ######### Random Encounters
  ####

  def random_dominant_inhabitants(chamber)
    log "Generating dominant inhabitants"
    return random_encounter(chamber, @dominant_inhabitants) unless @dominant_inhabitants.nil? or @dominant_inhabitants.empty? or not encounter_configuration["enable_dominant_inhabitants"]
    if encounter_configuration["enable_dominant_inhabitants"] != true
      log "Dominant inhabitants are not enabled"
    elsif @dominant_inhabitants.nil? or @dominant_inhabitants.empty?
      log_warn "Could not find any dominant inhabitants in the encounter table!"
    else
      raise "A problem occurred in random_dominant_inhabitants(). This should never be reached."
    end
    log "Using a random encounter instead"
    return random_encounter(chamber)
  end

  def random_allies(chamber)
    log "Generating allies"
    return random_encounter(chamber, @allies) unless @allies.nil? or @allies.empty? or not encounter_configuration["enable_allies"]
    if encounter_configuration["enable_allies"] != true
      log "Allies are not enabled"
    elsif @allies.nil? or @allies.empty?
      log_warn "Could not find any allies in the encounter table!"
    else
      raise "A problem occurred in random_allies(). This should never be reached."
    end
    log "Using a random encounter instead"
    return random_encounter(chamber)
  end

  def random_encounter(chamber, encounter_list = @random_encounters)
    # Allow input to be the chamber object or just the space available
    # Currently all we need is the chamber size
    space_available = (chamber.kind_of? Chamber) ? chamber.size : chamber
    size_category = (space_available > 1600) ? "large" : "small"
    if rand() < encounter_configuration["multiple_monster_group_chance"][size_category]
      encounter = random_monster_group((space_available / 2).to_i, encounter_list)
      encounter.add_monster_group(random_monster_group((space_available / 2).to_i, encounter_list).monster_groups[0])
    else
      encounter = random_monster_group(space_available, encounter_list)
    end
    log "Encounter Chosen:"
    log "  #{encounter.monster_groups[0].grouped_monster_lines.join(",")}"
    log "  #{encounter.monster_groups[1].grouped_monster_lines.join(",")}" if encounter.monster_groups.count == 2
    log "  XP: #{encounter.total_xp} - #{encounter.current_xp_threshold(party_xp_thresholds)}"
    @encounters_chosen = Array.new if @encounters_chosen.nil?
    @encounters_chosen << encounter
    return encounter
  end

  def random_monster_group(space_available, encounter_list = @random_encounters, max_tries = 3, try = 1)
    log "Attempting to find a suitable monster group, try #{try}"
    monster_group_proposal_count = 3
    xp_threshold_target = random_xp_threshold_target()
    monster_group_proposals = Array.new(monster_group_proposal_count) {
      e = weighted_random(encounter_list)
      min_xp, max_xp = encounter_xp_values(e["xp"])
      encounter = Encounter.new(e["encounter"], party_xp_thresholds, xp_threshold_target, space_available, min_xp, max_xp, e["probability"], e.fetch("special", false))
      probability = e.fetch("probability", 4)
      probability = (probability * 0.75).to_i unless encounter.current_xp_threshold(party_xp_thresholds) == xp_threshold_target
      probability = (probability * 0.75).to_i unless encounter.total_xp <= (party_xp_thresholds[:deadly] * max_xp_threshold_multiplier)
      probability = 1 if probability == 0
      probability = 0 if encounter.monster_groups.nil? or encounter.monster_groups[0].nil?
      {encounter: encounter, probability: probability}
    }
    if monster_group_proposals.any? { |mg| mg[:probability] > 0 }
      return weighted_random(monster_group_proposals)[:encounter]
    elsif try < max_tries
      return random_monster_group(space_available, encounter_list, max_tries, try+1)
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

  def level_appropriate_encounters(encounter_choices = random_encounter_choices)
    return nil if encounter_choices.nil?
    @level_appropriate_encounters = encounter_choices.select { |encounter|
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
    @encounter_configuration = $configuration["encounters"] if @encounter_configuration.nil?
    return @encounter_configuration
  end

  def dominant_inhabitant_choices()
    files = [encounter_configuration["choice_list_dominant_inhabitants"], encounter_configuration["choice_list_default"]]
    keys = ["dominant", "dominant_inhabitants", "encounters"]
    choices = encounter_choices(files, keys)
    log_error "Could not find any choices for dominant inhabitants!" if choices.nil?
    return choices
  end

  def ally_choices()
    files = [encounter_configuration["choice_list_allies"], encounter_configuration["choice_list_default"]]
    keys = ["allies", "encounters"]
    choices = encounter_choices(files, keys)
    log_error "Could not find any choices for allies/pets!" if choices.nil?
    return choices
  end

  def random_encounter_choices()
    files = [encounter_configuration["choice_list_random"], encounter_configuration["choice_list_default"]]
    keys = ["random", "encounters"]
    choices = encounter_choices(files, keys)
    log_error "Could not find any choices for random encounters!" if choices.nil?
    return choices
  end

  def encounter_choices(list_files, list_keys = ["encounters"])
    list_files = [list_files] unless list_files.kind_of? Array
    list_keys = [list_keys] unless list_keys.kind_of? Array
    list_files.each { |list_file|
      list_yaml = encounter_yaml(list_file)
      next if list_yaml.nil?
      list_keys.each { |key|
        return list_yaml[key] unless list_yaml[key].nil?
      }
      debug "Could not find encounter choices for #{list_file}"
      debug "Key choices: #{list_keys.join(", ")}"
    }
    return nil
  end

  def encounter_yaml(list_file)
    # TODO: Allow list_file to be a full path
    # Return nil if can't find file? Or allow an error?
    return nil if list_file.nil?
    return YAML.load(File.read("#{DATA_PATH}/encounters/#{list_file}.yaml"))
  end

  def max_xp_threshold_multiplier()
    encounter_configuration.fetch("max_xp_threshold_multiplier", 1.1)
  end
end