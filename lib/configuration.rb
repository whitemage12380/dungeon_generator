#!/bin/env ruby
require 'yaml'
require 'logger'
require_relative 'dungeon_generator_helper'

class Configuration < Hash
  def initialize()
    self.merge!(YAML.load_file(Configuration.configuration_path))
  end
  def self.configuration_path()
    "#{self.project_path}/conf/dungeon_generator.yaml"
  end
  def self.project_path()
    File.expand_path('../', File.dirname(__FILE__))
  end
end
$configuration = Configuration.new()