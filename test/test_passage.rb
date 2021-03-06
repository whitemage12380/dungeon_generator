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
  p = Passage.new(map: m, width: width, instructions: passage_instructions)
  p.rotate!
  p.rotate!
  p.rotate!
  p.rotate!
  puts p.to_s
  return p
end

def read_passage_instructions(passage_index)
  passages_data = YAML.load(File.read("#{__dir__}/../data/passages.yaml"))
  passage_data = passages_data["passages"][passage_index]
  passage_instructions = passage_data["passage"]
  return passage_instructions
end

def test_passage_rotate(passage_index:, width:, map_size: 40, turn: :left)
  p = test_passage(passage_index: passage_index, width: width, map_size: map_size)
  puts "----------------- Rotating #{turn} -------------------"
  p.rotate!(turn)
  puts p.to_s
end

def test_map_passage(passage_index:, width:, facing: :east, map_size: 40)
  passage_instructions = read_passage_instructions(passage_index)

  puts passage_instructions

  m = Map.new(map_size)
  m.add_passage(width: width, facing: facing, x: 12, y: 12, instructions: passage_instructions)
  puts "------MAP OBJECT--------"
  puts m.map_objects[0].to_s
  puts "--------MAP-------------"
  puts m.to_s
end

def test_map_connected_passage(passage_index:, width:, facing: :east, map_size: 40)
  passage_instructions = read_passage_instructions(passage_index)

  puts passage_instructions

  m = Map.new(map_size)
  m.add_passage(width: width, facing: facing, x: 12, y: 12, instructions: passage_instructions)
  connector = m.map_objects[0].connectors[0]
  m.add_passage(width: width, connector: connector, instructions: passage_instructions)
  puts "------MAP OBJECTS-------"
  puts m.map_objects[0].to_s
  puts "---"
  puts m.map_objects[1].to_s
  puts "--------MAP-------------"
  puts m.to_s
end

def test_map_conflicted_passage()
  passage_instructions = read_passage_instructions(0)
  m = Map.new(30)
  m.add_passage(width: 2, facing: :east, x: 12, y: 12, instructions: passage_instructions)
  m.add_passage(width: 2, facing: :north, x: 14, y: 15, instructions: passage_instructions)
  puts m.to_s
end

def test_map_boundary_passage()
  passage_instructions = read_passage_instructions(0)
  m = Map.new(20)
  m.add_passage(width: 2, facing: :north, x: 10, y: 2, instructions: passage_instructions)
  m.add_passage(width: 2, facing: :east, x: 18, y: 10, instructions: passage_instructions)
  m.add_passage(width: 2, facing: :south, x: 10, y: 18, instructions: passage_instructions)
  m.add_passage(width: 2, facing: :west, x: 2, y: 10, instructions: passage_instructions)
  puts m.to_s
end

def test_tee()
  puts "TEST: Tee Intersection"
  passage_instructions = ['FORWARD 10', 'TEE 10']
  m = Map.new(20)
  m.add_passage(width: 2, facing: :east, x: 2, y: 3, instructions: passage_instructions)
  m.add_passage(width: 2, facing: :east, x: 2, y: 9, instructions: read_passage_instructions(0))
  m.add_passage(width: 2, facing: :east, x: 2, y: 12, instructions: passage_instructions)
  m.add_passage(width: 2, facing: :east, x: 12, y: 15, instructions: read_passage_instructions(0))
  m.add_passage(width: 2, facing: :east, x: 12, y: 12, instructions: passage_instructions)
  puts m.to_s
end


#test_passage(passage_index: 4, width: 2)
#test_passage(passage_index: 4, width: 4)

#test_passage(passage_index: 0, width: 2) # STRAIGHT
#test_passage(passage_index: 1, width: 2) # DOOR RIGHT
#test_passage(passage_index: 2, width: 2) # DOOR LEFT
#test_passage(passage_index: 3, width: 2) # DOOR # Width 1 doesn't work yet
#test_passage(passage_index: 4, width: 2) # TURN RIGHT
#test_passage(passage_index: 5, width: 2) # TURN LEFT
#test_passage(passage_index: 6, width: 2) # SIDE PASSAGE RIGHT
#test_passage(passage_index: 7, width: 2) # SIDE PASSAGE RIGHT

#test_passage_rotate(passage_index: 0, width: 2, turn: :back)
#test_passage_rotate(passage_index: 4, width: 2, turn: 5)

#test_map_passage(passage_index: 0, width: 2, facing: :north)
#test_map_passage(passage_index: 0, width: 2, facing: :east)
#test_map_passage(passage_index: 0, width: 2, facing: :south)
#test_map_passage(passage_index: 0, width: 2, facing: :west)

#test_map_connected_passage(passage_index: 0, width: 2, facing: :north)
#test_map_connected_passage(passage_index: 0, width: 2, facing: :east)
#test_map_connected_passage(passage_index: 0, width: 2, facing: :south)
#test_map_connected_passage(passage_index: 4, width: 2, facing: :west)

#test_map_conflicted_passage()
#test_map_boundary_passage()
test_tee()