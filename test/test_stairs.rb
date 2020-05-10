#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/stairs'
require 'yaml'

def read_passage_instructions(passage_index)
  passages_data = YAML.load(File.read("#{__dir__}/../data/passages.yaml"))
  passage_data = passages_data["passages"][passage_index]
  passage_instructions = passage_data["passage"]
  return passage_instructions
end

def test_stairs(map_size = 40)
  puts "TEST: stairs"
  m = Map.new(map_size)
  s = m.add_stairs(x: 5, y:15, facing: :east, entrance_width: 2)
  puts s.to_s
  puts m.to_s
end

def test_stairs_from_passage(map_size = 40)
  puts "TEST: stairs from package"
  passage_instructions = read_passage_instructions(0)
  m = Map.new(map_size)
  p = m.add_passage(width: 2, x: 5, y:15, facing: :east, instructions: passage_instructions)
  s = m.add_stairs(connector: p.connectors[0])
  puts m.to_s
end

# test_stairs()
test_stairs_from_passage()