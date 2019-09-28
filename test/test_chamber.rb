#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/chamber'
require_relative '../lib/passage'
require 'yaml'

def test_chamber(chamber_index:, x:, y:, facing:, entrance_width: 2, map_size: 40)
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  c = Chamber.new(map: m, width: chamber_width, length: chamber_length, connector_x: x, connector_y: y, facing: facing, entrance_width: entrance_width)
end

def test_chamber_with_passages(passages:, chamber_index:, x:, y:, facing:, entrance_width: 2, map_size: 40)
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  passages.each {|p|
    puts p.to_s
    passage_instructions = read_passage_instructions(p[:passage_index])
    m.add_passage(width: p[:width], facing: p[:facing], x: p[:x], y: p[:y], instructions: passage_instructions)
  }
  c = Chamber.new(map: m, width: chamber_width, length: chamber_length, connector_x: x, connector_y: y, facing: facing, entrance_width: entrance_width)
  puts m.to_s
  puts c.to_s
end

def test_map_chamber_with_passages(passages:, chamber_index:, x:, y:, facing:, entrance_width: 2, map_size: 40)
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  passages.each {|p|
    puts p.to_s
    passage_instructions = read_passage_instructions(p[:passage_index])
    m.add_passage(width: p[:width], facing: p[:facing], x: p[:x], y: p[:y], instructions: passage_instructions)
  }
  m.add_chamber(width: chamber_width, length: chamber_length, x: x, y: y, facing: facing, entrance_width: entrance_width)
  puts m.to_s
end

def read_passage_instructions(passage_index)
  passages_data = YAML.load(File.read("#{__dir__}/../data/passages.yaml"))
  passage_data = passages_data["passages"][passage_index]
  passage_instructions = passage_data["passage"]
  return passage_instructions
end

#test_chamber(chamber_index: 0, x: -1, y: 4, facing: :east, map_size: 40)
#test_chamber(chamber_index: 1, x: -1, y: 2, facing: :east, map_size: 6)

#test_chamber(chamber_index: 0, x: 20, y: 20, facing: :north, map_size: 40)
#test_chamber(chamber_index: 0, x: 20, y: 20, facing: :west, map_size: 40)
#test_chamber(chamber_index: 0, x: 20, y: 20, facing: :south, map_size: 40)

test_map_chamber_with_passages(
  passages: [
    {width: 2, facing: :east, x: -1, y: 1, passage_index: 0},
    {width: 2, facing: :south, x: 3, y: 6, passage_index: 0},
  ],
  chamber_index: 2,
  x: -1,
  y: 4,
  facing: :east,
)