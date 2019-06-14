#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/chamber'
require 'yaml'

def test_chamber(chamber_index:, x:, y:, facing:, entrance_width: 2, map_size: 40)
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  c = Chamber.new(map: m, width: chamber_width, length: chamber_length, connector_x: x, connector_y: y, facing: facing, entrance_width: entrance_width)
end

test_chamber(chamber_index: 0, x: -1, y: 4, facing: :east)