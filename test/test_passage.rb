#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/passage'
require 'yaml'

def test_passage(passage_index:, width:, map_size: 40)
  passages_data = YAML.load(File.read("#{__dir__}/../data/passages.yaml"))
  passage_data = passages_data["passages"][passage_index]
  passage_instructions = passage_data["passage"]

  puts passage_instructions

  m = Map.new(map_size)
  p = Passage.new(m, width, passage_instructions)
  p.rotate!
  p.rotate!
  p.rotate!
  p.rotate!
  puts p.to_s
  return p
end

def test_passage_rotate(passage_index:, width:, map_size: 40, turn: :left)
  p = test_passage(passage_index: passage_index, width: width, map_size: map_size)
  puts "----------------- Rotating #{turn} -------------------"
  p.rotate!(turn)
  puts p.to_s
end

test_passage(passage_index: 0, width: 2)
#test_passage(passage_index: 4, width: 2)
#test_passage(passage_index: 4, width: 4)
test_passage(passage_index: 5, width: 4)

#test_passage_rotate(passage_index: 0, width: 2, turn: :back)
#test_passage_rotate(passage_index: 4, width: 2, turn: 5)

