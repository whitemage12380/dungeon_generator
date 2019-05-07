#!/usr/bin/ruby
require 'csv'
require 'generate_passage.rb'
require 'generate_chamber.rb'
starting_room_csv_path = "starting_room.csv"
passage_csv_path = "passage.csv"

def parse_starting_area_csv(file_path)
	return parse_passage_csv(file_path)
end

def print_room

