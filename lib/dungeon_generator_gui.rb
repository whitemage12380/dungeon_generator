require 'fox16'
require 'fox16/canvas'
require 'fox16/colors'
require_relative 'configuration'
require_relative 'map'
include Fox
include Canvas

class FillRectangleShape < RectangleShape

  attr_accessor :fillStyle, :fillRule

  def initialize(x, y, w, h)
    super(x, y, w, h)
    @fillStyle = FXDC::FILL_SOLID
    @fillRule = FXDC::RULE_EVEN_ODD
  end

  def draw(dc)
    oldForeground = dc.foreground
    oldFillStyle = dc.fillStyle
    oldFillRule = dc.fillRule
    dc.foreground = foreground
    dc.fillStyle = fillStyle
    dc.fillRule = fillRule
    dc.fillRectangle(x, y, width, height)
    dc.foreground = oldForeground
    dc.fillStyle = oldFillStyle
    dc.fillRule = oldFillRule
  end
end

class DungeonGeneratorGui < FXMainWindow

  SQUARE_PIXELS = 16
  EDGE_COORDINATES = {
    north: [0, 0, 1, 0],
    east: [1, 0, 1, 1],
    south: [1, 1, 0, 1],
    west: [0, 1, 0, 0]
  }

  def initialize(app, map)
    canvas_length = (map.size+1) * SQUARE_PIXELS
    window_width = canvas_length
    window_height = canvas_length + 20
    super(app, "Dungeon Generator", :width => window_width, :height => window_height)
    # Menu bar
    menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
    file_menu = FXMenuPane.new(self)
    FXMenuCommand.new(file_menu, "&New...")
    FXMenuTitle.new(menu_bar, "&File", nil, file_menu)
    #FXButton.new(self, "&Test", nil, app, FXApp::ID_QUIT)
    #@canvas = FXCanvas.new(self, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT)
    frame = FXHorizontalFrame.new(self,
      LAYOUT_FILL_X|LAYOUT_FILL_Y|FRAME_SUNKEN|FRAME_THICK,
      0, 0, 0, 0, 0, 0, 0, 0)
    scroll_area = FXScrollWindow.new(frame, :opts => LAYOUT_FILL)
      #LAYOUT_FIX_X|LAYOUT_FIX_Y,
      #0, 0, map.size * SQUARE_PIXELS, map.size * SQUARE_PIXELS)
    @canvas = ShapeCanvas.new(scroll_area, nil, 0, LAYOUT_FILL_X|LAYOUT_FILL_Y)
    #     @canvas = ShapeCanvas.new(scroll_area, nil, 0, LAYOUT_FIX_X|LAYOUT_FIX_Y, 0, 0, canvas_length, canvas_length)
    shapes = ShapeGroup.new()
    draw_grid(shapes, $configuration['map_size'], $configuration['map_size'])
    draw_map(shapes, map)
    @canvas.scene = shapes
    #shapes.each { |s| puts s.lineStyle if s.is_a? LineShape}
  end

  def draw_map(shapes, map)
    map.xlength.times { |x|
      map.ylength.times { |y|
        draw_map_square(shapes, x, y, map.square(x: x, y: y))
      }
    }
  end

  def draw_map_square(shapes, x, y, square)
#    return if square.nil?
    base_px = x * SQUARE_PIXELS
    base_py = y * SQUARE_PIXELS
    if square.nil?
      if $configuration['background_display'] == 'dark'
        shape = FillRectangleShape.new(
          base_px, base_py, SQUARE_PIXELS, SQUARE_PIXELS
        )
        shape.foreground = FXColor::DimGray
        shapes.addShape(shape)
        #fxdc = FXDCWindow.new(@canvas) do |dc|
        #  dc.foreground = FXColor::DimGray
        #  dc.fillRectangle(base_px, base_py, SQUARE_PIXELS, SQUARE_PIXELS)
        #end
        return
      end
    end
    if $configuration['map_display'] == 'debug'
      max_pixels = SQUARE_PIXELS - 1
      min_pixels = 1
    else
      max_pixels = SQUARE_PIXELS
      min_pixels = 0
    end
    # Draw each edge
    EDGE_COORDINATES.each_pair { |facing, coordinate_ratios|
      coordinates = [
        base_px + (coordinate_ratios[0] * (max_pixels - min_pixels)) + min_pixels,
        base_py + (coordinate_ratios[1] * (max_pixels - min_pixels)) + min_pixels,
        base_px + (coordinate_ratios[2] * (max_pixels - min_pixels)) + min_pixels,
        base_py + (coordinate_ratios[3] * (max_pixels - min_pixels)) + min_pixels
      ]
      edge_line = LineShape.new(*coordinates)
      case square.edges[facing]
      when :wall
        shapes.addShape(edge_line)
      when Door
        unless $configuration['map_display'] == 'debug'
          edge_line.lineWidth = 4
        end
        edge_line.foreground = FXColor::CornflowerBlue
        shapes.addShape(edge_line)
      when Connector
        if $configuration['map_display'] == 'debug'
          edge_line.foreground = FXColor::BlanchedAlmond
          shapes.addShape(edge_line)
        end
      end
    }
  end

  def draw_grid(shapes, width, height)
    width.times { |x|
      height.times { |y|
        px = x * SQUARE_PIXELS
        py = y * SQUARE_PIXELS
        dot = CircleShape.new(px, py, 0.5)
        dot.foreground = FXColor::BlanchedAlmond
        shapes.addShape(dot)
      }
    }
  end

  def create
    super                  # Create the windows
    show(PLACEMENT_SCREEN) # Make the main window appear
  end

end

#application = FXApp.new("Hello", "FoxTest")
#main = FXMainWindow.new(application, "Hello", nil, nil, DECOR_ALL)
#FXButton.new(main, "&Hello, World!", nil, application, FXApp::ID_QUIT)
#application.create()
#main.show(PLACEMENT_SCREEN)
#application.run()