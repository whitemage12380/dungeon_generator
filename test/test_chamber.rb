#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/chamber'
require_relative '../lib/passage'
require 'yaml'

def test_chamber(chamber_index:, x:, y:, facing:, entrance_width: 2, map_size: 40)
  puts "TEST: chamber"
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  c = Chamber.new(map: m, width: chamber_width, length: chamber_length, connector_x: x, connector_y: y, facing: facing, entrance_width: entrance_width)
end

def test_chamber_with_passages(passages:, chamber_index:, x:, y:, facing:, entrance_width: 2, map_size: 40)
  puts "TEST: chamber_with_passages"
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
  puts "TEST: map_chamber_with_passages"
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  passages.each {|p|
    passage_instructions = read_passage_instructions(p[:passage_index])
    m.add_passage(width: p[:width], facing: p[:facing], x: p[:x], y: p[:y], instructions: passage_instructions)
  }
  m.add_chamber(width: chamber_width, length: chamber_length, x: x, y: y, facing: facing, entrance_width: entrance_width)
  puts m.to_s
end

def test_connected_map_chamber(passage:, chamber_index:, map_size: 40)
  puts "TEST: connected_map_chamber"
  chambers_data = YAML.load(File.read("#{__dir__}/../data/chambers.yaml"))
  chamber_data = chambers_data["chambers"][chamber_index]
  chamber_width = chamber_data["width"]
  chamber_length = chamber_data["length"]
  m = Map.new(map_size)
  passage_instructions = read_passage_instructions(passage[:passage_index])
  p = Passage.new(map: m, width: passage[:width], facing: passage[:facing], connector_x: passage[:x], connector_y: passage[:y], instructions: passage_instructions)
  m.add_passage(passage: p)
  puts p.connectors.first.to_s
  m.add_chamber(width: chamber_width, length: chamber_length, connector: p.connectors.first)
  puts m.to_s
end

def test_chamber_exit(map_size = 40)
  puts "TEST: chamber_exit"
  m = Map.new(map_size)
  c = m.add_chamber(width: 6, length: 6, x: 5, y:15, facing: :east, entrance_width: 2)
  e = {location: :right, type: "door"}
  puts c.to_s
  puts c.connectors
  c.add_exit(e)
  puts m.to_s
  puts c.connectors
end

def test_chamber_random_exits(map_size = 40)
  puts "TEST: random_chamber_exits"
  m = Map.new(map_size)
  c = m.add_chamber(width: 6, length: 6, x: 5, y:15, facing: :east, entrance_width: 2)
  exits = MapGenerator.random_chamber_exits(c.size_category)
  puts c.to_s
  exits.each { |e|
    c.add_exit(e)
  }
  puts m.to_s
  puts c.connectors
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

#test_map_chamber_with_passages(
#  passages: [
#    {width: 2, facing: :east, x: -1, y: 1, passage_index: 0},
#    {width: 2, facing: :south, x: 3, y: 6, passage_index: 0},
#  ],
#  chamber_index: 2,
#  x: -1,
#  y: 4,
#  facing: :east,
#)

#test_connected_map_chamber(
#    passage: {width: 2, facing: :east, x: -1, y: 5, passage_index: 0},
#    chamber_index: 2,
#  )

#test_chamber_exit()

test_chamber_random_exits()
