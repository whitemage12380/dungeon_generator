require_relative 'configuration'
require_relative 'map_generator'

class Trap
  include DungeonGeneratorHelper

  attr_accessor :trigger, :severity, :effect, :dc

  def initialize(trigger: nil, severity: nil, effect: nil)
    trigger = MapGenerator.random_yaml_element("trap_triggers")["description"] if trigger.nil?
    severity = MapGenerator.random_yaml_element("trap_severities")["description"] if severity.nil?
    effect = MapGenerator.random_yaml_element("trap_effects")["description"] if effect.nil?
    @trigger = trigger
    @severity = severity
    @effect = effect
  end

  def generate_dc()
    @dc = case @severity.downcase
    when "setback"
      rand(10..11)
    when "dangerous"
      rand(12..15)
    when "deadly"
      rand(16..20)
    else
      raise "Unidentified severity: #{@severity}"
    end
  end

  def generate_attack()
    @attack = case @severity.downcase
    when "setback"
      rand(3..5)
    when "dangerous"
      rand(6..8)
    when "deadly"
      rand(9..12)
    else
      raise "Unidentified severity: #{@severity}"
    end
  end

  def damage()
    raise "Unsupported severity: #{@severity}" unless ['setback', 'dangerous', 'deadly'].include? @severity.downcase
    case $configuration['party_level']
    when 1..4
      case @severity.downcase
      when "setback"
        "1d10"
      when "dangerous"
        "2d10"
      when "deadly"
        "4d10"
      end
    when 5..10
      case @severity.downcase
      when "setback"
        "2d10"
      when "dangerous"
        "4d10"
      when "deadly"
        "10d10"
      end
    when 11..16
      case @severity.downcase
      when "setback"
        "4d10"
      when "dangerous"
        "10d10"
      when "deadly"
        "18d10"
      end
    when 17..20
      case @severity.downcase
      when "setback"
        "10d10"
      when "dangerous"
        "18d10"
      when "deadly"
        "24d10"
      end
    else
      raise "Unsupported party level: #{$configuration['party_level']}"
    end
  end

  def dc()
    generate_dc() if @dc.nil?
    @dc
  end

  def attack()
    generate_attack() if @attack.nil?
    @attack
  end

  def to_h()
    {trigger: @trigger, severity: @severity, effect: @effect}
  end

  def to_s()
    [
      "Trigger:  #{@trigger}",
      "Severity: #{@severity} (DC #{@dc}, +#{@attack} to hit, #{damage} damage)",
      "Effect:   #{@effect}",
    ].join("\n")
  end
end