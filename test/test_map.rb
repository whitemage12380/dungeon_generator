#!/usr/bin/env ruby
require_relative '../lib/map_generator'
require 'yaml'

def read_passage_instructions(passage_index)
  passages_data = YAML.load(File.read("#{__dir__}/../data/passages.yaml"))
  passage_data = passages_data["passages"][passage_index]
  passage_instructions = passage_data["passage"]
  return passage_instructions
end


def test_connected_passages(starting_passage:, passages:, map_size: 60)
  m = Map.new(map_size)
  passage_instructions = read_passage_instructions(starting_passage[:passage_index])
  next_passage = m.add_passage(width: starting_passage[:width], facing: starting_passage[:facing], x: starting_passage[:x], y: starting_passage[:y], instructions: passage_instructions)
  passages.each { |p|
    puts next_passage.connectors.first.to_s
    next_passage = m.add_passage(connector: next_passage.connectors.first, width: p[:width], instructions: read_passage_instructions(p[:passage_index]))
  }
  puts m.to_s
end

def test_map_generator()
  m = MapGenerator.generate_map()
  puts m.to_s
end

def test_random_exits()
  puts "Normal test:"
  puts MapGenerator.random_chamber_exits("normal")
  puts "Large test:"
  puts MapGenerator.random_chamber_exits("large")
end

def test_random_chamber_contents()
  puts "TEST: Random chamber contents"
  puts MapGenerator.generate_chamber_contents().to_s
end

def test_connect_to_existing(map_size: 60)
  puts "TEST: Connect passage to existing object"
  m = Map.new(map_size)
  m.add_chamber(width: 6, length: 6, x: 6, y: 6, facing: :east, entrance_width: 2)
  m.add_passage(width: 2, x: 3, y: 6, facing: :east, instructions: read_passage_instructions(0))
  puts m.to_s
end

def test_save(map_size: 60)
  puts "TEST: Save map to file"
  m = MapGenerator.generate_map()
  m.save("testmap")
end

#test_connected_passages(
#  starting_passage: {width: 2, facing: :east, x: -1, y: 20, passage_index: 0},
#  passages: [
#    {width: 2, passage_index: 0},
#    {width: 2, passage_index: 4},
#    {width: 2, passage_index: 5},
#  ],
#)

#test_map_generator()
#test_random_exits()
test_random_chamber_contents()
#test_connect_to_existing()
#test_save()