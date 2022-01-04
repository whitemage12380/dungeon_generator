require 'optparse'
require_relative 'dungeon_generator_helper'

class DgenCli
  extend DungeonGeneratorHelper

  AVAILABLE_COMMANDS = [
  'encounter',
  'encountertable',
  'feature',
  'features',
  'featureset',
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

    def command_encounter(*args)
    
    end

    def command_encountertable(*args)
    end

    def command_feature(*args)
    
    end

    def command_features(*args)
    
    end

    def command_featureset(*args)
    
    end

    def command_hazard(*args)
      return random_yaml_element("hazards")["description"]
    end

    def command_item(*args)
    
    end

    def command_monster(*args)
    
    end

    def command_monsters(*args)
    
    end

    def command_monstergroup(*args)
    
    end

    def command_obstacle(*args)
      return random_yaml_element("obstacles")["description"]
    end

    def command_room(*args)
    
    end

    def command_roomtype(*args)
    
    end

    def command_trap(*args)
      require_relative 'trap'
      trap = Trap.new()
      trap.generate_dc() # TODO: Figure out why Trap is set up to require setting these separately from init
      trap.generate_attack()
      return trap.to_s()
    end

    def command_treasure(*args)
      require_relative 'treasure_stash'
      return TreasureStash.new(true).to_s()
    end

    def command_trick(*args)
      require_relative 'trick'
      return Trick.new().to_s()
    end
  end
end