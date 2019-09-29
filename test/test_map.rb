#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/chamber'
require_relative '../lib/passage'
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

test_connected_passages(
  starting_passage: {width: 2, facing: :east, x: -1, y: 20, passage_index: 0},
  passages: [
    {width: 2, passage_index: 0},
    {width: 2, passage_index: 4},
    {width: 2, passage_index: 5},
  ],
)