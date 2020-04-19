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
  include DungeonGeneratorHelper

  SQUARE_PIXELS = 16
  SIDEBAR_PIXELS = 200
  EDGE_COORDINATES = {
    north: [0, 0, 1, 0],
    east: [1, 0, 1, 1],
    south: [1, 1, 0, 1],
    west: [0, 1, 0, 0]
  }

  def initialize(app, map)
    @app = app
    canvas_length = (map.size+1) * SQUARE_PIXELS
    window_width = canvas_length + SIDEBAR_PIXELS + 20
    window_height = canvas_length + 80
    super(app, "Dungeon Generator", :width => window_width, :height => window_height)
    # Menu bar
    menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
    file_menu = FXMenuPane.new(self)
    FXMenuCommand.new(file_menu, "&New...")
    FXMenuTitle.new(menu_bar, "&File", nil, file_menu)
    # Main Window Structure
    @frame = FXHorizontalFrame.new(self,
      LAYOUT_SIDE_TOP|LAYOUT_FILL_X|LAYOUT_FILL_Y|FRAME_SUNKEN|FRAME_THICK,
      #FRAME_SUNKEN|FRAME_THICK,
      0, 0, 800, 800, 0, 0, 0, 0)
    @left_frame = FXVerticalFrame.new(@frame, 
      FRAME_SUNKEN|LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT,
      :padLeft => 10, :padRight => 10, :padTop => 10, :padBottom => 10)   
    @right_frame = FXVerticalFrame.new(@frame, 
      FRAME_SUNKEN|LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT|LAYOUT_FIX_WIDTH,
      :width => SIDEBAR_PIXELS, :padLeft => 10, :padRight => 10, :padTop => 10, :padBottom => 10)
    # Left Pane
    @dungeon_name = FXLabel.new(@left_frame, "Dungeon", nil, JUSTIFY_CENTER_X|LAYOUT_FILL_X)
    FXHorizontalSeparator.new(@left_frame, SEPARATOR_GROOVE|LAYOUT_FILL_X)
    @canvas = ShapeCanvas.new(@left_frame, nil, 0,
      LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT|LAYOUT_TOP|LAYOUT_LEFT, 0, 0, canvas_length, canvas_length)
    # Right Pane
    @info_title = FXLabel.new(@right_frame, "Info", nil, JUSTIFY_CENTER_X|LAYOUT_FILL_X)
    FXHorizontalSeparator.new(@right_frame, SEPARATOR_RIDGE|LAYOUT_FILL_X)

    @info_panel = FXVerticalFrame.new(@right_frame,
      LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT|LAYOUT_FILL_X,
      :padLeft => 0, :padRight => 0, :padTop => 0, :padBottom => 0)
    @info_panel_sections = {
      description: {
        header: header(@info_panel, "Description"),
        content: paragraph(@info_panel, "Nothing yet"),
      },
      exits: {
        header: header(@info_panel, "Exits"),
        content: paragraph(@info_panel, "Nothing yet"),
      }
    }
    #header(@info_panel, "Description")
    @info_panel.hide()


    draw_canvas(@canvas, map)
    connect_canvas(@canvas, map)
  end

  def draw_canvas(canvas, map)
    canvas.backColor = FXColor::White
    if $configuration['background_display'] == 'dark'
      canvas.backColor = FXColor::DimGray
    end
    shapes = ShapeGroup.new()
    draw_map(shapes, map)
    draw_grid(shapes, $configuration['map_size'], $configuration['map_size'])
    draw_empty(shapes, map)
    canvas.scene = shapes
  end

  def draw_map(shapes, map)
    map.xlength.times { |x|
      map.ylength.times { |y|
        draw_map_square(shapes, x, y, map.square(x: x, y: y))
      }
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

  def draw_empty(shapes, map)
    map.xlength.times { |x|
      map.ylength.times { |y|
        draw_empty_square(shapes, x, y) if map.square(x: x, y: y).nil?
      }
    }
  end

  def draw_map_square(shapes, x, y, square)
    base_px = x * SQUARE_PIXELS
    base_py = y * SQUARE_PIXELS
    return if square.nil?
    shape = FillRectangleShape.new(base_px, base_py, SQUARE_PIXELS, SQUARE_PIXELS)
    shape.foreground = FXColor::WhiteSmoke
    shapes.addShape(shape)
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

  def draw_empty_square(shapes, x, y)
    base_px = x * SQUARE_PIXELS
    base_py = y * SQUARE_PIXELS
    if $configuration['background_display'] == 'dark'
      shape = FillRectangleShape.new(
        base_px, base_py, SQUARE_PIXELS, SQUARE_PIXELS
      )
      shape.foreground = FXColor::DimGray
      shapes.addShape(shape)
    end
  end

  def display_map_object_info(map_object)
    #@info_display = FXVerticalFrame.new(@right_frame,
    #   FRAME_SUNKEN|LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT,
    #  )
      #:padLeft => 10, :padRight => 10, :padTop => 10, :padBottom => 10)
    #@info_display.backColor = FXColor::Blue
    #header(@info_display, "Description")
    @info_panel.show()
  end

  #def info_section(parent, header_text)
  #  section = FXVerticalFrame.new(parent, LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT|LAYOUT_FILL_X)
  #end

  def header(parent, text)
    label = FXLabel.new(parent, text, nil, JUSTIFY_LEFT|LAYOUT_FILL_X)
    label.font = FXFont.new(@app, "helvetica,120,bold,normal,normal,iso8859-1,0")
    return label
  end

  def paragraph(parent, text)
    paragraph = FXLabel.new(parent, text, nil, JUSTIFY_LEFT|LAYOUT_FILL_X)
    paragraph.font = FXFont.new(@app, "helvetica,100,normal,normal,normal,iso8859-1,0")
    return paragraph
  end

  def list(parent, list_items)
  end

  def connect_canvas(canvas, map)
    canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, selector, event|
      selected_map_coordinates = {x: event.click_x / SQUARE_PIXELS, y: event.click_y / SQUARE_PIXELS}
      selected_square = map.square(selected_map_coordinates)
      if selected_square.nil?
        log "Clicked an empty square or outside the map boundary (#{selected_map_coordinates})"
        next
      end
      selected_map_object = selected_square.map_object
      log "Selected #{selected_map_object.name}"
      @info_title.text = selected_map_object.name
      display_map_object_info(selected_map_object)
    end
  end

  def create
    super                  # Create the windows
    show(PLACEMENT_SCREEN) # Make the main window appear
  end

end