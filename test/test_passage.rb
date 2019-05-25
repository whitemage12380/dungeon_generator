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


#test_passage(passage_index: 4, width: 2)
#test_passage(passage_index: 4, width: 4)
test_passage(passage_index: 0, width: 2)
test_passage(passage_index: 1, width: 2) # DOOR RIGHT
test_passage(passage_index: 2, width: 2) # DOOR LEFT
test_passage(passage_index: 3, width: 2) # Width 1 doesn't work yet
test_passage(passage_index: 4, width: 2)
test_passage(passage_index: 5, width: 2)
test_passage(passage_index: 6, width: 2) # SIDE PASSAGE RIGHT
test_passage(passage_index: 7, width: 2) # SIDE PASSAGE RIGHT
#test_passage_rotate(passage_index: 0, width: 2, turn: :back)
#test_passage_rotate(passage_index: 4, width: 2, turn: 5)

