require_relative 'configuration'
require_relative 'map'
require 'yaml'

class MapGenerator
  FACINGS = [:north, :east, :south, :west]
  class << self
    include DungeonGeneratorHelper

    def generate_map(map_size = $configuration['map_size'])
      log "Beginning map generation"
      map = Map.new(map_size)
      starting_area = map.generate_starting_area()
      starting_area.connectors.each {|c| generate_passage_recursive(c)}
      log "Completed map generation"
      log "Passage count: #{map.passages.length}"
      log "Chamber count: #{map.chambers.length}"
      map.save()
      return map
    end

    def generate_starting_area_configuration()
      # Starting with a simple passage
      starting_area = yaml_data("passages", 0)
      starting_area["width"] = 2
      return starting_area
    end

    def generate_starting_area_location(map, width = 2)
      log "Determining reasonable random location for starting area"
      map_size = map.xlength
      # Maximum length of starting area is 16 squares. To best accommodate, always choose a side if map is under 40 squares.
      if map_size < 40
        return [
          {x: -1, y: (map_size/2), facing: :east},
          {x: (map_size/2), y: -1, facing: :south},
          {x: map_size, y: (map_size/2), facing: :west},
          {x: (map-size/2), y: map_size, facing: :north},
        ].sample
      end
      # These configurations should either by configurable or dynamic based on what the starting area is
      edge_buffer = 4
      edge_facing_buffer = 20
      # Generate random location
      rand_x = rand(-1..map_size)
      rand_y = rand(-1..map_size)
      log "Random coordinates: (#{rand_x}, #{rand_y})"
      # Get info based on whether x and y are close to map edges
      x_buffered, y_buffered = nil
      x_buffered = [edge_buffer, [rand_x, map_size - edge_buffer - 1].min].max if rand_x < edge_buffer or rand_x >= map_size - edge_buffer
      y_buffered = [edge_buffer, [rand_y, map_size - edge_buffer - 1].min].max if rand_y < edge_buffer or rand_y >= map_size - edge_buffer
      debug "x_buffered: [#{edge_buffer}, [#{rand_x}, #{map_size} - #{edge_buffer} - 1].min].max}"
      debug "y_buffered: [#{edge_buffer}, [#{rand_y}, #{map_size} - #{edge_buffer} - 1].min].max}"
      log "Buffered coordinates: (#{x_buffered}, #{y_buffered})" if x_buffered or y_buffered
      # Corner case: Bump out x or y so that it is no longer in a corner
      if x_buffered and y_buffered
        if rand(1) == 0 # Flip a coin to determine whether to buffer out x or y
          rand_x = x_buffered
        else
          rand_y = y_buffered
        end
      end
      # Edge case: Prevent the starting area from facing straight into the edge of the map
      facing_exceptions = []
      facing_exceptions << :east  if rand_x >= map_size - edge_facing_buffer or rand_y + width > map_size
      facing_exceptions << :south if rand_y >= map_size - edge_facing_buffer or rand_x - width < -1
      facing_exceptions << :west  if rand_x < edge_facing_buffer             or rand_y - width < -1
      facing_exceptions << :north if rand_y < edge_facing_buffer             or rand_x + width > map_size
      # Edge case: If -1 or map_size has been generated, must face away.
      facing = :east  if rand_x == -1
      facing = :south if rand_y == -1
      facing = :west  if rand_x == map_size
      facing = :north if rand_y == map_size
      # Decide on facing
      facing = random_facing(facing_exceptions) unless facing
      # Location generated
      return {x: rand_x, y: rand_y, facing: facing}
    end

    def generate_passage_recursive(connector)
      #chamber_strategy = :wait # immediate: generate from chamber when it appears. 
      #                         # wait: Generate from chambers after passages are complete
      map = connector.map_object.map
      if connector.connecting_map_object.nil?
        if connector.kind_of? Door
          log "Generating new map object beyond door"
          passage_data = random_yaml_element("beyond_door")
        else
          log "Generating new map object"
          passage_data = random_yaml_element("passages")
        end
      else
        log "Found existing connected map object"
        passage_data = {"passage" => "Already Exists"}
      end
      debug "Data: #{passage_data.to_s}"
      case passage_data["passage"]
      when "chamber"
        log "Type: Chamber"
        chamber_data = random_yaml_element("chambers")
        width = chamber_data["width"]
        length = chamber_data["length"]
        chamber = map.add_chamber(connector: connector, width: width, length: length)
        unless chamber.nil?
          chamber.add_exits()
          chamber.connectors.each { |c|
            generate_passage_recursive(c)
          }
          chamber.doors.each { |d|
            generate_passage_recursive(d)
          }
        end
      when "stairs"
        log "Type: Stairs"
        log "Stairs not implemented"
      else
        log "Type: Passage"
        if connector.connecting_map_object.nil?
          passage = map.add_passage(connector: connector, instructions: passage_data["passage"])
        else
          # The SO bug is somewhere in here or has_incomplete_connectors?.
          # It might be that two passages get connected to each other and both have another connector,
          # But those connectors never happen because they keep bouncing back and forth between each other.
          # Won't work if connecting_map_object ends up being a chamber (not currently possible)
          passage = map.add_passage(passage: connector.connecting_map_object)
          return unless passage and passage.has_incomplete_connectors?
        end
        unless passage.nil?
          passage.all_connectors.each {|c|
            generate_passage_recursive(c)
          }
        end
      end
    end

    def random_chamber_exits(size_category)
      exit_count = random_yaml_element("chamber_exits")[size_category]
      log "Generating #{exit_count} exits for chamber"
      exits = []
      for i in 0...exit_count
        exit_location = random_yaml_element("exit_locations")["facing"].to_sym
        exit_type = random_yaml_element("exit_types")
        exit_obj = {location: exit_location, type: exit_type["type"]}
        exit_obj[:passage] = exit_type["passage"] if exit_type["type"] == "passage"
        exits << exit_obj
        log "Generated exit: #{exit_obj.to_s}"
      end
      return exits
    end

    def random_facing(exceptions = [])
      available_facings = FACINGS - exceptions
      return available_facings.sample
    end

    def random_yaml_element(type)
      yaml_data(type)
    end

    def yaml_data(type, index = nil)
      arr = YAML.load(File.read("#{__dir__}/../data/#{type}.yaml"))[type]
      return weighted_random(arr) unless index
      return arr[index]
    end

    def weighted_random(arr)
      weighted_arr = []
      arr.each { |elem|
        elem["probability"].times do
          weighted_arr << elem
        end
      }
      return weighted_arr.sample
    end
  end
end