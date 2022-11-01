require_relative 'configuration'
require_relative 'map'
require 'victor'

class DungeonSvg
  include Victor
  include DungeonGeneratorHelper

  SQUARE_PIXELS = 70
  WALL_PIXELS = 8
  DOOR_PIXELS = 16
  DOOR_LENGTH_RATIO = 0.7 # Percentage of squares door stretches across (centered)
  COLORS = {
    background: '#DDDDDD',
    chamber: '#7A757C',
    door: '#DDDDDD',
    passage: '#7A757C',
    stairs: '#4A959C',
    wall: '#38343A',
  }
  STYLES = {
    chamber: {stroke: COLORS[:chamber], fill: COLORS[:chamber]},
    door: {stroke: '#000000', stroke_width: 2, fill: COLORS[:door]},
    passage: {stroke: COLORS[:passage], fill: COLORS[:passage]},
    stairs: {stroke: COLORS[:stairs], fill: COLORS[:stairs]},
    wall: {stroke: COLORS[:wall], stroke_width: WALL_PIXELS},
  }

  def initialize(map, filename = "#{Configuration.project_path}/data/svg")
    @map = map
    size = @map.size * SQUARE_PIXELS
    @svg = SVG.new(width: size, height: size, style: { background: COLORS[:background] })
    @doors_added = Array.new()
    svg_chambers()
    svg_passages()
    svg_stairs()
    svg_doors()
    file = File.expand_path(filename)
    log "SVG Export: Saving to #{file}"
    @svg.save(file)
    map.svg_file = file
  end

  def svg_chambers(map = @map, svg = @svg)
    map.chambers.each { |chamber|
      log "SVG Export: Drawing #{chamber.label}"
      svg.g {
        svg_chamber(chamber)
      }
    }
  end

  def svg_passages(map = @map, svg = @svg)
    map.passages.each { |passage|
      log "SVG Export: Drawing #{passage.label}"
      svg.g {
        svg_passage(passage)
      }
    }
  end

  def svg_stairs(map = @map, svg = @svg)
    map.stairs.each { |staircase|
      log "SVG Export: Drawing #{staircase.label}"
      svg.g {
        svg_staircase(staircase)
      }
    }
  end

  def svg_chamber(chamber, svg = @svg)
    x = chamber.abs_map_pos[:x] * SQUARE_PIXELS
    y = chamber.abs_map_pos[:y] * SQUARE_PIXELS
    width = chamber.abs_width * SQUARE_PIXELS
    height = chamber.abs_length * SQUARE_PIXELS
    svg.rect(x: x, y: y, width: width, height: height, style: STYLES[:chamber])
    svg_map_object_walls(chamber)
  end

  def svg_passage(passage)
    svg_map_object_floor(passage)
    svg_map_object_walls(passage)
  end

  def svg_staircase(stairs, svg = @svg)
    x = stairs.map_offset_x * SQUARE_PIXELS
    y = stairs.map_offset_y * SQUARE_PIXELS
    width = stairs.abs_width * SQUARE_PIXELS
    height = stairs.abs_length * SQUARE_PIXELS
    svg.rect(x: x, y: y, width: width, height: height, style: STYLES[:stairs])
    svg_map_object_walls(stairs)
  end

  def svg_map_object_floor(map_object, style = :passage)
    svg = @svg
    map_object.grid.length.times { |x|
      map_object.grid[x].length.times { |y|
        square = map_object.grid[x][y]
        next if square.nil?
        x_px = (x + map_object.map_offset_x) * SQUARE_PIXELS
        y_px = (y + map_object.map_offset_y) * SQUARE_PIXELS
        svg.rect(x: x_px, y: y_px, width: SQUARE_PIXELS, height: SQUARE_PIXELS, style: STYLES[style])
      }
    }
  end

  def svg_map_object_walls(map_object)
    svg = @svg
    map_object.grid.length.times { |x|
      map_object.grid[x].length.times { |y|
        square = map_object.grid[x][y]
        next if square.nil?
        x1_px = (x + map_object.map_offset_x) * SQUARE_PIXELS
        y1_px = (y + map_object.map_offset_y) * SQUARE_PIXELS
        x2_px = x1_px + SQUARE_PIXELS
        y2_px = y1_px + SQUARE_PIXELS
        svg.line(x1: x1_px, x2: x2_px, y1: y1_px, y2: y1_px, style: STYLES[:wall]) unless square.facing_open?(:north)
        svg.line(x1: x1_px, x2: x2_px, y1: y2_px, y2: y2_px, style: STYLES[:wall]) unless square.facing_open?(:south)
        svg.line(x1: x2_px, x2: x2_px, y1: y1_px, y2: y2_px, style: STYLES[:wall]) unless square.facing_open?(:east)
        svg.line(x1: x1_px, x2: x1_px, y1: y1_px, y2: y2_px, style: STYLES[:wall]) unless square.facing_open?(:west)
      }
    }
  end

  def svg_doors()
    svg = @svg
    @map.doors.each { |door| svg_door(door) }
  end

  def svg_door(door)
    svg = @svg
    pos = door.abs_map_pos()
    x_px = pos[:x] * SQUARE_PIXELS
    y_px = pos[:y] * SQUARE_PIXELS
    depth_px = DOOR_PIXELS
    length_px = (door.width * SQUARE_PIXELS) * DOOR_LENGTH_RATIO
    length_offset = ((door.width * SQUARE_PIXELS) * (1 - DOOR_LENGTH_RATIO)) / 2
    depth_offset = depth_px / 2
    case door.facing
    when :north, :south
      svg.rect(x: x_px + length_offset, y: y_px - depth_offset,  width: length_px, height: depth_px,  style: STYLES[:door])
    when :east, :west
      svg.rect(x: x_px - depth_offset,  y: y_px + length_offset, width: depth_px,  height: length_px, style: STYLES[:door])
    else
      raise "Door direction not allowed: #{direction}"
    end
  end
end