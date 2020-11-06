#!/usr/bin/env ruby
require_relative '../lib/encounter_table'
require 'yaml'

e = EncounterTable.new()
#puts e.generate_encounter_list
#puts e.generate_dominant_inhabitants.to_s
puts e.random_encounter(20)