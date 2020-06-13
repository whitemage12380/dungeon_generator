require 'gtk3'
require 'fileutils'
require_relative 'configuration'
require_relative 'map_generator'

class DungeonGeneratorInfoPanel < Gtk::Box
  include DungeonGeneratorHelper
  type_register
  class << self
    def init
      set_template(resource: "/ui/dungeon_generator_info_panel.ui")
    end
  end
  def initialize()
    super()
  end
end

class DungeonGeneratorWindow < Gtk::ApplicationWindow
  include DungeonGeneratorHelper
  type_register

  SQUARE_PIXELS = 16
  WALL_PIXELS = 2
  DOOR_PIXELS = 6
  DOOR_LENGTH_RATIO = 0.7 # Percentage of squares door stretches across (centered)
  EDGE_COORDINATES = {
    north: [0, 0, 1, 0],
    east: [1, 0, 1, 1],
    south: [1, 1, 0, 1],
    west: [0, 1, 0, 0]
  }
  COLOR = {
    connector:             'BlanchedAlmond',
    door:                  'CornflowerBlue',
    dungeon_room:          'WhiteSmoke',
    dungeon_solid:         'DimGray',
    grid:                  'BlanchedAlmond',
    stairs:                'PaleGreen',
    text_edit_background:  'WhiteSmoke',
    wall:                  'DarkSlateGray',
  }

  class << self
    def init
      set_template(resource: "/ui/dungeon_generator_window.ui")
      bind_template_child('map_canvas')
      bind_template_child('info_pane')
    end
  end

  def initialize(application, map = nil)
    super(application: application)
    info_panel = DungeonGeneratorInfoPanel.new()
    info_pane.pack_start(info_panel)
    load_map()
    map_canvas.signal_connect('draw') do |map_canvas, ctx|
      #ctx.set_line_width(10.0)
      #ctx.set_source_rgb(0.8, 0.0, 0.0);
      #ctx.move_to(0,0)
      #ctx.line_to(map_canvas.width,map_canvas.height)
      #ctx.stroke()
      #puts ctx.methods
      draw_map(ctx)
    end
  end

  def load_map(map = nil)
    map = MapGenerator.generate_map() if map.nil?
    @map = map
  end

  def draw_map(ctx, map = @map)
    draw_map_background(ctx)
    draw_map_squares(ctx, map)
    draw_grid(ctx, map.size, map.size)
    draw_empty_squares(ctx, map)
    draw_walls(ctx,map)
  end

  def draw_map_background(ctx)
    ctx.save()
    set_color(ctx, COLOR[:dungeon_solid])
    ctx.paint()
    ctx.restore()
  end

  def draw_map_squares(ctx, map = @map)
    map.each_square { |square, x, y|
      draw_map_square(ctx, square, x, y)
    }
  end

  def draw_empty_squares(ctx, map = @map)
    map.each_square { |square, x, y|
      draw_empty_square(ctx, x, y) if square.nil?
    }
  end

  def draw_walls(ctx, map = @map)
    map.each_square { |square, x, y|
      draw_map_square_edges(ctx, square, x, y)
    }
  end

  def draw_map_square(ctx, square, x, y)
    return if square.nil?
    base_px = x * SQUARE_PIXELS
    base_py = y * SQUARE_PIXELS
    ctx.save()
    if square.map_object.kind_of? Stairs
      set_color(ctx, COLOR[:stairs])
    else
      set_color(ctx, COLOR[:dungeon_room])
    end
    ctx.move_to(base_px, base_py)
    ctx.rectangle(base_px, base_py, SQUARE_PIXELS, SQUARE_PIXELS)
    ctx.stroke_preserve()
    ctx.fill()
    ctx.restore()
  end

  def draw_map_square_edges(ctx, square, x, y)
    return if square.nil?
    base_px = x * SQUARE_PIXELS
    base_py = y * SQUARE_PIXELS
    ctx.save()
    if $configuration['map_display'] == 'debug'
      max_pixels = SQUARE_PIXELS - 1
      min_pixels = 1
    else
      max_pixels = SQUARE_PIXELS
      min_pixels = 0
    end
    EDGE_COORDINATES.each_pair { |facing, coordinate_ratios|
      coordinates = [
        base_px + (coordinate_ratios[0] * (max_pixels - min_pixels)) + min_pixels,
        base_py + (coordinate_ratios[1] * (max_pixels - min_pixels)) + min_pixels,
        base_px + (coordinate_ratios[2] * (max_pixels - min_pixels)) + min_pixels,
        base_py + (coordinate_ratios[3] * (max_pixels - min_pixels)) + min_pixels
      ]
      set_color(ctx, COLOR[:wall])
      ctx.set_line_width(WALL_PIXELS)
      ctx.move_to(coordinates[0], coordinates[1])
      ctx.line_to(coordinates[2], coordinates[3]) unless square.facing_open?(facing)
      ctx.stroke()
      if $configuration['map_display'] == 'debug' and square.has_connector(facing)
        set_color(ctx, COLOR[:connector])
        ctx.set_line_width(1)
        ctx.line_to(coordinates[2], coordinates[3])
        ctx.stroke()
      end
    }
    ctx.restore()
  end

  def draw_empty_square(ctx, x, y)
    base_px = x * SQUARE_PIXELS
    base_py = y * SQUARE_PIXELS
    ctx.save()
    set_color(ctx, COLOR[:dungeon_solid])
    ctx.move_to(base_px, base_py)
    ctx.rectangle(base_px, base_py, SQUARE_PIXELS, SQUARE_PIXELS)
    ctx.stroke_preserve()
    ctx.fill()
    ctx.restore()
  end

  def draw_grid(ctx, width, height)
    ctx.save()
    set_color(ctx, COLOR[:grid])
    width.times { |x|
      height.times { |y|
        px = x * SQUARE_PIXELS
        py = y * SQUARE_PIXELS
        ctx.move_to(px, py)
        ctx.circle(px, py, 1)
      }
    }
    ctx.stroke()
    ctx.restore()
  end

  def set_color(ctx, color)
    ctx.set_source_color(Gdk::Color.parse(color))
  end
  
end

class DungeonGeneratorGui < Gtk::Application
  include DungeonGeneratorHelper
  
  def initialize()
    super('com.github.whitemage12380.dungeon_generator', Gio::ApplicationFlags::FLAGS_NONE)
    signal_connect :activate do |application|
      window = DungeonGeneratorWindow.new(application)
      window.present
    end
  end
end

gresource_bin = "#{Configuration.project_path}/resources/dungeon_generator.gresource"
gresource_xml = "#{Configuration.project_path}/resources/dungeon_generator.gresource.xml"
gresource_source = "#{File.dirname(gresource_xml)}/ui"

######### CANNED RESOURCE SETUP ##########
system("glib-compile-resources",
       "--target", gresource_bin,
       "--sourcedir", gresource_source,
       gresource_xml)
at_exit do
  FileUtils.rm_f(gresource_bin)
end
resource = Gio::Resource.load(gresource_bin)
Gio::Resources.register(resource)
##########################################

app = DungeonGeneratorGui.new

puts app.run