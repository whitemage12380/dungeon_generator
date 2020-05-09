require_relative 'configuration'

module DungeonGeneratorHelper
  require 'stringio'
  require 'logger'

  def init_logger()
    $log = Logger.new(STDOUT) if $log.nil?
    $log.level = $configuration['log_level'] ? $configuration['log_level'].upcase : Logger::INFO
    $messages = StringIO.new() if $messages.nil?
    $message_log = Logger.new($messages) if $message_log.nil?
    $message_log.level = Logger::INFO
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

  def log_important(message)
    init_logger()
    $log.info(message)
    $message_log.info(message)
  end

  def print_messages()
    unless $message_log.nil? or $messages.nil?
      puts "Important messages:"
      puts $messages.string
      $message_log = nil
      $messages = nil
    end
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