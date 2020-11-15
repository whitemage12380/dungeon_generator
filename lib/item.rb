require_relative 'configuration'

class Item
  include DungeonGeneratorHelper
  attr_reader :name, :worth

  def initialize(name, worth = nil, roll = nil, table = nil, tags = nil)
    @name = name
    @worth = worth
    generate_subitem(roll) unless roll.nil?
    generate_details(table, tags) unless table.nil?
  end

  def generate_subitem(roll)
    @name = weighted_random(roll)['name']
  end

  def generate_details(table, tags = {})
    tags = Hash.new if tags.nil?
    require_tags = tags[:require] || []
    exclude_tags = tags[:exclude] || []
    puts table.to_s
    puts tags.to_s
    puts require_tags.to_s
    puts exclude_tags.to_s
    possible_items = YAML.load(File.read("#{DATA_PATH}/treasure/items/#{table}.yaml"))
      .select { |i| require_tags.all? { |t| i.fetch('tags', []).include? t } }
      .reject { |i| exclude_tags.any? { |t| i.fetch('tags', []).include? t } }
    item = weighted_random(possible_items)['name']
    @name = "#{@name} (#{item})"
  end

  def to_s()
    @worth.nil? ? @name : "#{@name} (#{@worth} gp)"
  end
end