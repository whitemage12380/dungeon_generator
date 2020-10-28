require_relative 'configuration'
require_relative 'map_generator'

class Monster
  include DungeonGeneratorHelper
  attr_reader :name, :size, :type, :tags, :alignment, :challenge, :xp, :book, :page

  @@monster_data = YAML.load(File.read("#{DATA_PATH}/monsters.yaml"))

  def initialize(name)
    m = @@monster_data.find { |x| x["name"].downcase == name.downcase }
    #puts m.to_s
    @name = name
    @size = m["size"]
    @type = m["type"]
    @alignment = m["alignment"]
    @challenge = m["challenge"]
    @xp = m["xp"]
    @book = m["book"]
    @page = m["page"]
  end

  def squares(size_str = size)
    case size_str
    when "tiny", "small", "medium"
      1
    when "large"
      4
    when "huge"
      9
    when "gargantuan"
      16
    else
      raise "Invalid monster size label: #{size_str}"
    end
  end
end