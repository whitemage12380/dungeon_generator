require_relative 'configuration'
require_relative 'map'
require 'victor'

class DungeonSvg
  include Victor

  SQUARE_PIXELS = 20
  STYLES = {

  }
  COLORS = {
    background: '#ddd',
    floor: '#7A757C',
  }

  def initialize(map)
    @map = map
    size = @map.size * SQUARE_PIXELS
    @svg = SVG.new(width: size, height: size, style: { background: COLORS[:background] })
    chambers = svg_chambers()
    #puts "Appending chambers..."
    #@svg << chambers
    #@svg.rect(x: 2, y: 2, width: 200, height: 200)
    @svg.save(File.expand_path('data/svg/mytest'))
  end

# There are a few ways to set this up. The simplest way would be to just draw squares on each occupied cell in one giant group.
# Possibly better would be to group each map object individually.
# It would also be possible to draw a single rectangle for chambers, and handle passages cell-by-cell, if that would have any positive impact.
# Drawing passages as a single polygon would be tricky since I'd have to generate that polygon info from the cell layout.

  def svg_floors()
    svg = SVG.new()
    svg.build {
      g {
        map.map_objects.each { |obj|
        #  x = 
        #   rect()
        }
      }
    }
  end

  def svg_chambers(map = @map)
    #svg = SVG.new()
    svg = @svg
    #svg.build {
      map.chambers.each { |chamber|
        puts "Drawing #{chamber.id_str}"
        svg.g {
          svg_chamber_floor(chamber)
          #append(svg_chamber_floor(chamber))
          #append(svg_chamber_walls(chamber))
        }
      }
    #}

  end

  def svg_chamber_walls(chamber)
  end

  def svg_chamber_floor(chamber)
    #svg = SVG.new()
    svg = @svg
    x = chamber.abs_map_pos[:x] * SQUARE_PIXELS
    y = chamber.abs_map_pos[:y] * SQUARE_PIXELS
    width = chamber.abs_width * SQUARE_PIXELS
    height = chamber.abs_length * SQUARE_PIXELS
    svg.rect(x: x, y: y, width: width, height: height, style: {stroke: '#ccc', fill: COLORS[:floor]})
    return svg
  end

  def svg_walls()
  end

  def svg_doors()
  end


    # @map.xlength.times { |x|
    #   @map.ylength.times { |y|
    #     draw_map_square(shapes, x, y, map.square(x: x, y: y))
    #   }
    # }
end