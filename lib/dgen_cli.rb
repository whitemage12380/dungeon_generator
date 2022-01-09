require 'optparse'
require_relative 'dungeon_generator_helper'

class DgenCli
  extend DungeonGeneratorHelper

  AVAILABLE_COMMANDS = [
  'chamber',
  'chambertype',
  'encounter',
  'encountertable',
  'feature',
  'features',
  'hazard',
  'item',
  'monster',
  'monsters',
  'monstergroup',
  'obstacle',
  'room',
  'roomtype',
  'trap',
  'treasure',
  'trick',
]
  class << self

    def execute(*args)
      $configuration['log_level'] = 'warn'
      init_logger()
      parse_arguments(args)
      command = args.shift()
      output = send("command_#{command}", *args)
      puts output
    end

    def parse_arguments(args)
      args = ["-h"] if args.empty?
      optparse = OptionParser.new do |opts|
        opts.banner = "Usage: dgen command [subcommand ...] [options]"
        opts.on("-lLEVEL", "--level", "Party level") do |v|
          $configuration['party_level'] = v.to_i
        end
        opts.on("-mMEMBERS", "--members=MEMBERS", "Number of party members") do |v|
          $configuration['party_members'] = v.to_i
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end
      begin
        optparse.parse!(args)
        command = args.first
        raise OptionParser::MissingArgument if command.nil?
        raise OptionParser::InvalidArgument unless AVAILABLE_COMMANDS.include?(command)
      rescue OptionParser::InvalidOption, OptionParser::InvalidArgument, OptionParser::MissingArgument => e
        if command.nil?
          puts "No command found."
        elsif not AVAILABLE_COMMANDS.include?(command)
          puts "Invalid command: #{command}"
        else
          puts e.to_s
        end
        usage(optparse)
      end
    end

    def usage(optparse, exit_code = 0)
      puts "Available Commands:"
      puts AVAILABLE_COMMANDS.collect { |c| "  #{c}" }.join("\n")
      puts optparse
      exit exit_code
    end

    def command_chamber(*args)
      require_relative 'map_generator'
      return MapGenerator.generate_map.chambers.sample.to_s
    end

    def command_chambertype(*args)
      require_relative 'map_generator'
      purpose = MapGenerator.generate_chamber_purpose()
      return [
        purpose["name"],
        purpose["description"]
      ].join("\n")
    end

    def command_encounter(*args)
      return random_encounter.flatten.sample.to_s
    end

    def command_encountertable(*args)
      require_relative 'encounter_table'
      return EncounterTable.new.to_s
    end

    def command_feature(*args)
      require_relative 'map_generator'
      return MapGenerator.generate_map.chambers.reject { |c| c.contents[:features].empty? }
        .sample.contents[:features].flatten.sample.to_s
    end

    def command_features(*args)
      require_relative 'map_generator'
      return MapGenerator.generate_map.chambers.reject { |c| c.contents[:features].empty? }
        .sample.contents[:features].flatten.collect { |f| f.to_s }.join("\n")
    end

    def command_hazard(*args)
      return random_yaml_element("hazards")["description"]
    end

    def command_item(*args)
      require_relative 'treasure_stash'
      return TreasureStash.new(true).random_treasure('items', 1).first.to_s
    end

    def command_monster(*args)
      return random_encounter.first.monster_groups.first.sample.to_s
    end

    def command_monsters(*args)
      return command_monstergroup(*args)
    end

    def command_monstergroup(*args)
      return random_encounter.first.monster_groups.first.to_s(include_motivation: true)
    end

    def command_obstacle(*args)
      return random_yaml_element("obstacles")["description"]
    end

    def command_room(*args)
      command_chamber(*args)
    end

    def command_roomtype(*args)
      command_chambertype(*args)
    end

    def command_trap(*args)
      require_relative 'trap'
      return Trap.new.to_s
    end

    def command_treasure(*args)
      require_relative 'treasure_stash'
      return TreasureStash.new(true).to_s
    end

    def command_trick(*args)
      require_relative 'trick'
      return Trick.new.to_s
    end

    def random_encounter()
      require_relative 'map_generator'
      contents_with_monsters = read_datafile("chamber_contents")["chamber_contents"]
        .select { |c|
          ["dominant_monster", "monster_ally", "monster_random"].any? { |m|
            c["contents"] and c["contents"].include? m
          }
        }
      contents_yaml = weighted_random(contents_with_monsters)
      chamber = MapGenerator.generate_map.chambers.sample
      chamber.generate_contents(contents_yaml)
      return chamber.contents[:monsters]
    end
  end
end