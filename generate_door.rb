#!/usr/bin/ruby
require 'csv'
require_relative 'generate_passage'
require_relative 'generate_chamber'
door_type_csv_path = "door_type.csv"
beyond_door_csv_path = "beyond_door.csv"

def parse_door_type_csv(file_path)
	table = []
	CSV.foreach(file_path,{ :col_sep => "\t", :headers => true }) do |row|
		probability = row[0]
		description = row[1]
		for i in 0..probability.to_i-1
			table.push({:description => description})
		end
	end
	return table
end

def parse_beyond_door_csv(file_path)
	table = []
	CSV.foreach(file_path,{ :col_sep => "\t", :headers => true }) do |row|
		probability = row[0]
		description = row[1]
		destination = row[2]
		for i in 0..probability.to_i-1
			table.push({:description => description, :destination => destination})
		end
	end
	return table
end

def add_door()
	random_door_type = $door_type_table[rand($door_type_table.length)]
	random_beyond_door = $beyond_door_table[rand($beyond_door_table.length)]
	door = {:door_type => random_door_type[:description], :beyond_door_description => random_beyond_door[:description], :beyond_door_destination => random_beyond_door[:destination]}
	case door[:beyond_door_destination]
	when "passage"
		random_passage_width = $passage_width_table[rand($passage_width_table.length)]
		door[:passage_width] = random_passage_width[:description]
		door[:exit] = add_passage()
	when "chamber"
		puts "Skipping chambers for now"
	when "stairs"
		puts "Skipping stairs for now"
	end
	return door
end

def print_door(door, depth=0)
	indent = depth * 4
	print_indent(indent)
	puts "#{door[:door_type]}."
	print_indent(indent)
	puts "#{door[:beyond_door_description]}."
	case door[:beyond_door_destination]
	when "passage"
		print_indent(indent)
		puts "Width is #{door[:passage_width]}"
		print_passage(door[:exit], depth+1)
	when "chamber"
		puts "Skipping chambers for now"
	when "stairs"
		puts "Skipping stairs for now"
	end
end

$door_type_table = parse_door_type_csv(door_type_csv_path)
$beyond_door_table = parse_beyond_door_csv(beyond_door_csv_path)
