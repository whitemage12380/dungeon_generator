#!/usr/bin/env ruby
require_relative '../lib/map'
require_relative '../lib/passage'
require 'yaml'

passages_data = YAML.load(File.read("#{__dir__}/../data/passages.yaml"))
width = 2
passage_data = passages_data["passages"][0]
passage_instructions = passage_data["passage"]

puts passage_instructions

m = Map.new(40)
p = Passage.new(m, width, passage_instructions)
