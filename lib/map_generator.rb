require_relative 'configuration'
require_relative 'map'
require_relative 'monster_group'
require_relative 'trap'
require_relative 'trick'
require 'yaml'

class MapGenerator
  extend DungeonGeneratorHelper

  class << self
    def generate_map(map_size = $configuration['map_size'], theme: nil)
      log "Beginning map generation"
      map = Map.new(map_size)
      starting_area = map.generate_starting_area()
      starting_area.all_connectors.each {|c| generate_passage_recursive(c)}
      log "Completed map generation"
      log "Passage count: #{map.passages.length}"
      log "Chamber count: #{map.chambers.length}"
      print_messages()
      map.save()
      return map
    end

    ########################################
    #### STARTING AREA
    ########################################

    def generate_starting_area_configuration()
      random_yaml_element("starting_areas")
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

    ########################################
    #### MAIN MAP GENERATION LOGIC
    ########################################

    def generate_passage_recursive(connector)
      #chamber_strategy = :wait # immediate: generate from chamber when it appears. 
      #                         # wait: Generate from chambers after passages are complete
      map = connector.map_object.map
      from_map_object = connector.map_object
      to_map_object = connector.connecting_map_object
      if to_map_object and to_map_object.drawn?
        log "Map object #{to_map_object.name} is already connected and drawn, skipping generation step from #{from_map_object.name}"
        return
      end
      if to_map_object.nil?
        if connector.kind_of? Door
          log "Generating new map object beyond door from #{from_map_object.name}"
          passage_data = random_yaml_element("beyond_door")
        else
          log "Generating new map object from #{from_map_object.name}"
          passage_data = random_yaml_element("passages")
          passage_data["type"] = "passage" if passage_data["type"].nil?
        end
      else
        log "Found existing connected map object: #{to_map_object.name}"
        passage_data = {"type" => to_map_object.type}
        if to_map_object.type != "passage"
          raise "Existing map objects other than passages are not supported in generate_passage_recursive"
        end
      end
      debug "Data: #{passage_data.to_s}"
      case passage_data["type"]
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
        stairs = map.add_stairs(connector: connector)
      else
        log "Type: Passage"
        if to_map_object.nil?
          passage = map.add_passage(connector: connector, instructions: passage_data["passage"])
        else
          debug "#{connector.connecting_map_object.name} already exists"
          unless to_map_object.kind_of? Passage
            log_important "#{to_map_object.name} is not a passage but got assumed to be such in the generator! This should never happen."
            return
          end
          passage = map.add_passage(connector: connector, passage: to_map_object)
          return unless passage and passage.has_incomplete_connectors?
        end
        unless passage.nil?
          passage.all_connectors.each {|c|
            generate_passage_recursive(c)
          }
        end
      end
    end

    ########################################
    #### EXITS
    ########################################

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

    ########################################
    #### THEME AND PURPOSE
    ########################################

    def generate_chamber_purpose(map = nil)
      if map.nil?
        theme = $configuration.fetch('theme', all_themes.sample)
      else
        theme = map.themes.sample
      end
      return random_chamber_purpose(theme)
    end

    def select_themes()
      theme = $configuration.fetch('theme', 'random')
      if theme == 'random'
        theme_tables = $configuration.fetch('theme_tables', 1)
        theme_table_list = $configuration.fetch('theme_table_list', 'all')
        if theme_table_list == 'all'
          theme_table_list = all_themes()
        end
        theme_table_list.sample(theme_tables)
      else
        theme
      end
    end

    def random_theme()
      return all_themes.sample
    end

    def all_themes()
      return Dir["#{DATA_PATH}/chamber_purpose/*.yaml"].collect { |f| File.basename(f, ".yaml") }
    end

    def random_chamber_purpose(theme)
      random_yaml_element("chamber_purpose/#{theme}").merge({"theme" => theme})
    end

    ########################################
    #### MISC
    ########################################

    def random_facing(exceptions = [])
      available_facings = FACINGS - exceptions
      return available_facings.sample
    end

  end
end