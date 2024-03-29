require_relative 'configuration'
require_relative 'item'

class TreasureStash
  include DungeonGeneratorHelper
  attr_reader :coins, :valuables, :items, :treasure_table, :treasure_level

  def initialize(generate = false, treasure_level = 1, party_level = $configuration['party_level'])
    generate(treasure_level, party_level) if generate
  end

  def generate(treasure_level = 1, party_level = $configuration['party_level'])
    treasure_tables = YAML.load(File.read("#{DATA_PATH}/treasure.yaml"))['treasure']
    treasure_table_level = treasure_tables.keys.sort.reduce(1) { |memo, level|
      ((level > memo) and (level < party_level)) ? level : memo
    }
    @treasure_table = treasure_tables[treasure_table_level]
    @treasure_level = treasure_level
    treasure_counts = random_treasure_counts()
    generate_coins(treasure_counts['coins'])
    generate_valuables(treasure_counts['valuables'])
    generate_items(treasure_counts['items'])
  end

  def random_treasure_counts(treasure_table = @treasure_table, treasure_level = @treasure_level)
    treasure_counts = {"coins" => 0, "valuables" => 0, "items" => 0}
    base_treasure_type = ["coins", "valuables", "items"].sample
    treasure_counts[base_treasure_type] += 1
    treasure_table.keys.each { |type|
      log "Initial treasure chance for #{type}: #{treasure_configuration['initial_treasure_chance']} + #{treasure_level * 0.1} = #{treasure_configuration['initial_treasure_chance'] + (treasure_level * 0.1)}"
      if rand() < treasure_configuration['initial_treasure_chance'] + (treasure_level * 0.1)
        treasure_counts[type] += 1
        extra_treasure_chance = treasure_configuration['extra_treasure_chance']
        treasure_configuration['extra_treasure_max'].times do
          log "Extra treasure chance: #{extra_treasure_chance} + #{treasure_level * 0.1} = #{extra_treasure_chance + (treasure_level * 0.1)}"
          break unless rand() < extra_treasure_chance + (treasure_level * 0.1)
          treasure_counts[type] += 1
          extra_treasure_chance -= 0.1
        end
      end
    }
    return treasure_counts
  end

  def generate_coins(count, treasure_table = @treasure_table)
    coins_table = treasure_table['coins'].to_a.collect { |c| {'type' => c[0]}.merge(c[1]) }
    @coins = Hash.new
    count.times do
      coin_data = weighted_random(coins_table)
      @coins[coin_data['type']] = 0 if @coins[coin_data['type']].nil?
      min, max = coin_data['count'].split('-').collect(&:to_i)
      @coins[coin_data['type']] += rand(max - min + 1) + min
    end
  end

  def generate_valuables(count, treasure_table = @treasure_table)
    @valuables = random_treasure('valuables', count, treasure_table)
  end

  def generate_items(count, treasure_table = @treasure_table)
    @items = random_treasure('items', count, treasure_table)
  end

  def random_treasure(type, count, treasure_table = @treasure_table)
    table = treasure_table[type].to_a.collect { |c| {'type' => c[0]}.merge(c[1]) }
    chosen_items = Array.new
    count.times do
      treasure_data = weighted_random(table)
      if treasure_data['type'] =~ /_[0-9]+$/
        worth = treasure_data['type'].split("_").last.to_i
      end
      case treasure_data['count']
      when Integer
        min, max = Array.new(2) { treasure_data['count'] }
      when /^([0-9]+)-([0-9]+)$/
        min, max = [$1.to_i, $2.to_i]
      when nil
        min, max = [1, 1]
      else
        raise "Could not parse count for treasure data: #{treasure_data.to_s}"
      end
      treasure_count = rand(max - min + 1) + min
      treasure_count.times do
        chosen_item = weighted_random(YAML.load(File.read("#{DATA_PATH}/treasure/#{type}/#{treasure_data['type']}.yaml")))
        worth = chosen_item['worth'] unless chosen_item['worth'].nil? # Worth may already be set so don't nil it out
        tags = {require: chosen_item['tags'], exclude: chosen_item['not_tags']}
        chosen_items << Item.new(chosen_item['name'], worth, chosen_item['roll'], chosen_item['table'], tags)
      end
    end
    return chosen_items.sort_by { |i| i.name }
  end

  def treasure_configuration()
    $configuration['treasure']
  end

  def to_s_lines()
    [
      @coins.empty? ? nil : ["Coins"] + @coins.collect { |coin_type, coins| "  #{coins} #{coin_type}" },
      @valuables.empty? ? nil : ["Valuables"] + @valuables.collect { |item| "  #{item.to_s}" },
      @items.empty? ? nil : ["Items"] + @items.collect { |item| "  #{item.to_s}" },
    ].flatten.compact
  end

  def to_s()
    to_s_lines.join("\n")
  end
end