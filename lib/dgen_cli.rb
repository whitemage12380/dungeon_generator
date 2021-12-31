require 'optparse'

class DgenCli

  AVAILABLE_COMMANDS = [
  'encounter',
  'feature',
  'features',
  'featureset',
  'hazard',
  'item',
  'monster',
  'monsters',
  'monstergroup',
  'room',
  'roomtype',
  'trap',
  'treasure',
  'trick',
]
  class << self

    def execute(*args)
      command = args.shift()
      raise ArgumentError.new("No command found") if command.nil?
      raise ArgumentError.new("Invalid command: #{command}") unless AVAILABLE_COMMANDS.include?(command)
      send("command_#{command}", *args)
    end

    def command_encounter(*args)
    
    end

    def command_feature(*args)
    
    end

    def command_features(*args)
    
    end

    def command_featureset(*args)
    
    end

    def command_hazard(*args)
    
    end

    def command_item(*args)
    
    end

    def command_monster(*args)
    
    end

    def command_monsters(*args)
    
    end

    def command_monstergroup(*args)
    
    end

    def command_room(*args)
    
    end

    def command_roomtype(*args)
    
    end

    def command_trap(*args)
    
    end

    def command_treasure(*args)
    
    end

    def command_trick(*args)
    
    end
  end
end