require_relative 'configuration'

class Trap
  include DungeonGeneratorHelper

  attr_accessor :trigger, :severity, :effect

  def initialize(trigger: nil, severity: nil, effect: nil)
    trigger = MapGenerator.random_yaml_element("trap_triggers")["description"] if trigger.nil?
    severity = MapGenerator.random_yaml_element("trap_severities")["description"] if severity.nil?
    effect = MapGenerator.random_yaml_element("trap_effects")["description"] if effect.nil?
    log_important trigger
    log_important severity
    log_important effect
    @trigger = trigger
    @severity = severity
    @effect = effect
  end

  def to_h()
    {trigger: @trigger, severity: @severity, effect: @effect}
  end
end