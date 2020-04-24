require_relative 'configuration'

module DungeonGeneratorHelper
  require 'logger'

  def init_logger()
    $log = Logger.new(STDOUT) if $log.nil?
    $log.level = $configuration['log_level'] ? $configuration['log_level'].upcase : Logger::INFO
  end

  def debug(message)
    init_logger()
    $log.debug(message)
  end

  def log(message)
    init_logger()
    $log.info(message)
  end

  def log_error(message)
    init_logger()
    $log.error(message)
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

end