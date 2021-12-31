#!/bin/env ruby
require 'yaml'
require 'logger'
require_relative 'dungeon_generator_helper'

class Configuration < Hash

  attr_accessor :indent

  def initialize(quiet: false)
    self.deep_merge!(YAML.load_file(Configuration.default_configuration_path))
    self.deep_merge!(YAML.load_file(Configuration.configuration_path))
    self.transform_values! { |v|
      if v.kind_of? String
        case v.downcase
        when "true", "on", "yes"
          true
        when "false", "off", "no"
          false
        else
          v
        end
      else
        v
      end
    }
    puts "Configurations loaded: #{to_s}" unless quiet
  end

  def self.configuration_path()
    "#{self.project_path}/conf/dungeon_generator.yaml"
  end

  def self.default_configuration_path()
    "#{self.project_path}/conf/dungeon_generator.defaults.yaml"
  end

  def self.project_path()
    File.expand_path('../', File.dirname(__FILE__))
  end
end
