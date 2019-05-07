#!/usr/bin/ruby
require 'csv'
require 'optparse'
require './generate_passage.rb'
require './generate_door.rb'

# CSV File paths
#
$passage_csv_path = "passage.csv"
$passage_width_csv_path = "passage_width.csv"
$door_type_csv_path = "door_type.csv"
$beyond_door_csv_path = "beyond_door.csv"

# Configuration parameters
#$max_depth
options = {}
OptionParser.new do |opts|
	opts.banner = "Usage: generate.rb [options]"
	opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
		options[:verbose] = v
	end
	opts.on("-M","--max-depth DEPTH", "Set maximum depth") do |depth|
		options[:max_depth] = depth
	end
end.parse!

# Main program execution

$passage_table = parse_passage_csv($passage_csv_path)
$passage_width_table = parse_passage_width_csv($passage_width_csv_path)
$door_type_table = parse_door_type_csv($door_type_csv_path)
$beyond_door_table = parse_beyond_door_csv($beyond_door_csv_path)

passage = add_passage()

print_passage(passage)
