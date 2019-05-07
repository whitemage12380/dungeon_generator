#!/usr/bin/ruby
require 'csv'
require_relative "generate_door"
passage_csv_path = "passage.csv"
passage_width_csv_path = "passage_width.csv"

def parse_passage_csv(file_path)
	table = []
	CSV.foreach(file_path,{ :col_sep => "\t", :headers => true }) do |row|
		probability = row[0]
		passages = row[1]
		doors = row[2]
		description = row[3]
		destination = row[4]
		for i in 0..probability.to_i-1
			table.push({:passage_count => passages, :door_count => doors, :description => description, :destination => destination})
		end
	end
	return table
end

def parse_passage_width_csv(file_path)
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

def add_passage(depth=0)
	random_passage = $passage_table[rand($passage_table.length)]
	if depth == 0
		random_passage_width = $passage_width_table[rand($passage_width_table.length)]
	else
		random_passage_width = $passage_width_table[rand(12)]
	end
	passage = {:detail => random_passage[:description], :passage_count => random_passage[:passage_count], :door_count => random_passage[:door_count], :destination => random_passage[:destination],  :width => random_passage_width[:description] }
	passage[:passages] = []
	passage[:doors] = []
	depth += 1
	for i in 0..passage[:passage_count].to_i-1
		puts "Adding passage recursively"
		passage[:passages].push(add_passage(depth))
	end
	for i in 0..passage[:door_count].to_i-1
		passage[:doors].push(add_door())
		puts "Adding door"
	end
	return passage
end

def print_passage(passage, depth=0)
	indent = depth * 4
	if depth == 0
		puts("PASSAGE DESCRIPTION:")
		puts
	end
	print_indent(indent)
	puts "#{passage[:detail]}."
	if ! passage[:destination]
		print_indent(indent)
		puts "Width is #{passage[:width]}"
	end

	for i in 0..passage[:passage_count].to_i-1
		print_indent(indent)
		puts "Route #{i}:"
		print_passage(passage[:passages][i], depth+1)
	end

	for i in 0..passage[:door_count].to_i-1
		print_indent(indent)
		puts "Door #{i}:"
		print_door(passage[:doors][i], depth+1)
	end
	
end

def print_indent(indent)
	for i in 1..indent
		print " "
	end
end


# Main program execution

$passage_table = parse_passage_csv(passage_csv_path)
$passage_width_table = parse_passage_width_csv(passage_width_csv_path)

passage = add_passage()

print_passage(passage)
