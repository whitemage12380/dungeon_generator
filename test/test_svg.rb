#!/usr/bin/env ruby
require_relative '../lib/dungeon_svg'
require_relative '../lib/map_generator'
require 'yaml'

def test_basic_svg()
  m = Map.new(20)
  DungeonSvg.new(m)
end

def test_random_map_svg()
   m = MapGenerator.generate_map()
   puts m.to_s
   DungeonSvg.new(m)
end

def blarg()
  m = Map.load("latest")
  DungeonSvg.new(m)
end

#test_basic_svg()
#test_random_map_svg()
blarg()
