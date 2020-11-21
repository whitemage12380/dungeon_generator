require_relative 'configuration'

class Feature
  include DungeonGeneratorHelper
  attr_reader :table, :name, :contents

  def initialize(table, feature_data)
    raise "Could not find name for feature (#{feature_data.to_s})" if feature_data['name'].nil?
    @name = feature_data['name']
    @table = table
    @contents = Array.new()
    generate_contents(feature_data['contents']) unless feature_data['contents'].nil?
  end

  def generate_contents(contents_data)
    contents_data.each_pair { |table, count|
      @contents.concat read_datafile("features/#{table}").sample(random_count(count)).collect { |f| Feature.new(table, f) }
    }
  end

  def to_s()
    output = case @table
    when 'books'
      "Book: #{@name}"
    when 'scrolls'
      "Scroll: #{@name}"
    else
      @name
    end
    unless @contents.nil? or @contents.empty?
      output += " (#{@contents.collect { |c| c.to_s }.join(", ")})"
    end
    return output
  end
end