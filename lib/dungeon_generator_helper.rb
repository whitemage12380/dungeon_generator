require_relative 'configuration'

class ::String
  def pretty()
    output = split(/ |\_/).map(&:capitalize).join(" ")
            .split("-").map(&:capitalize).join("-")
            .split("(").map(&:capitalize).join("(")
    output = capitalize.gsub(/_/, " ")
            .gsub(/\b(?<!\w['])[a-z]/) { |match| match.capitalize }
    return output
  end
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red()
    colorize(31)
  end

  def green()
    colorize(32)
  end

  def yellow()
    colorize(33)
  end

  def blue()
    colorize(34)
  end

  def pink()
    colorize(35)
  end

  def light_blue()
    colorize(36)
  end
end

class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        self.merge(second, &merger)
    end

    def deep_merge!(second)
      merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      self.merge!(second, &merger)
    end
end

module DungeonGeneratorHelper
  require 'stringio'
  require 'logger'

  DATA_PATH = "#{__dir__}/../data"
  FACINGS = [:north, :east, :south, :west]

  def init_logger()
    $log = Logger.new(STDOUT) if $log.nil?
    $log.level = $configuration['log_level'] ? $configuration['log_level'].upcase : Logger::INFO
    $messages = StringIO.new() if $messages.nil?
    $message_log = Logger.new($messages) if $message_log.nil?
    $message_log.level = Logger::INFO
    $configuration.indent = "" if $configuration.indent.nil?
  end

  def debug(message)
    init_logger()
    $log.debug($configuration.indent + message)
  end

  def log(message)
    init_logger()
    $log.info($configuration.indent + message)
  end

  def log_error(message)
    init_logger()
    $log.error($configuration.indent + message)
  end

  def log_important(message)
    init_logger()
    $log.info($configuration.indent + message)
    $message_log.info($configuration.indent + message)
  end

  def print_messages()
    unless $message_log.nil? or $messages.nil?
      puts "Important messages:"
      puts $messages.string
      $message_log = nil
      $messages = nil
    end
  end

  def log_indent()
    $configuration.indent = "  "
  end

  def log_outdent()
    $configuration.indent = ""
  end

  def opposite_facing(facing)
    case facing
    when :north; return :south
    when :east; return :west
    when :south; return :north
    when :west; return :east
    else return nil
    end
  end

  def party_xp_thresholds(party_level = $configuration["party_level"], party_members = $configuration["party_members"])
    @xp_threshold_table = YAML.load(File.read("#{DATA_PATH}/xp_thresholds.yaml"))["xp_thresholds"] if @xp_threshold_table.nil?
    t = @xp_threshold_table[party_level]
    {easy: t[0] * party_members, medium: t[1] * party_members, hard: t[2] * party_members, deadly: t[3] * party_members}
  end

  def xp_threshold(xp)
    t = party_xp_thresholds
    return :impossible if xp > (t[:deadly] * 2)
    return :deadly if xp > t[:deadly]
    return :hard if xp > t[:hard]
    return :medium if xp > t[:medium]
    return :easy if xp > t[:easy]
    return :trivial
  end

  def random_count(count)
    return count if count.kind_of? Integer
    min, max = count.split('-').collect(&:to_i)
    max = min if max.nil?
    rand(Range.new(min, max))
  end

  def read_datafile(file)
    YAML.load(File.read("#{DATA_PATH}/#{file}.yaml"))
  end

  def random_yaml_element(type_path, type = nil)
    yaml_data(type_path, type)
  end

  def yaml_data(type_path, type = nil, index = nil)
    type = type_path.split("/").last if type.nil?
    obj = YAML.load(File.read("#{DATA_PATH}/#{type_path}.yaml"))
    arr = (type == :none) ? obj : obj[type]
    return weighted_random(arr) unless index
    return arr[index]
  end

  def weighted_random(arr)
    weighted_arr = []
    arr.each { |elem|
      probability = ((elem.kind_of? Hash) and elem["probability"]) ? elem["probability"] : 1
      probability.times do
        weighted_arr << elem
      end
    }
    return weighted_arr.sample
  end

end