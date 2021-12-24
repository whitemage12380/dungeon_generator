require 'gtk3'
require 'fileutils'
require_relative 'configuration'
require_relative 'map_generator'
require_relative 'dungeon_generator_gtk_helper'
require_relative 'dungeon_generator_gtk_info_panel'

class DungeonGeneratorWindow < Gtk::ApplicationWindow
  include DungeonGeneratorGtkHelper
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
      ### MAP HEADER ###
      bind_template_child('map_header')
      bind_template_child('map_header_stack')
      bind_template_child('map_header_edit')
      bind_template_child('map_header_eventbox')
      bind_template_child('map_menu_button')
      bind_template_child('toggle_map_details_button')
      ### PANES ###
      bind_template_child('panes')
      bind_template_child('map_stack')
      bind_template_child('info_pane')
      ### MAP ###
      bind_template_child('map_scroll')
      bind_template_child('map_canvas')
      ### MAP DETAILS ###
      bind_template_child('map_details')
      bind_template_child('text_map_description')
      ### NEW MAP ###
      bind_template_child('new_map_options_scroll')
      bind_template_child('new_map_option_party_members')
      bind_template_child('new_map_option_party_level')
      bind_template_child('button_new_map')
      bind_template_child('button_new_map_cancel')
    end
  end

  def initialize(application, map = nil)
    super(application: application)
    setup_map_menu()
    load_info_panel()
    load_map()

    ### MAP HEADER ###
    map_header_eventbox.add_events(:button_press_mask)
    map_header_eventbox.signal_connect('button-press-event') do |eventbox, event, user_data|
      map_header_edit.set_text(map_header.title)
      map_header_stack.set_visible_child(map_header_edit)
      map_header_edit.grab_focus()
    end
    map_header_edit.signal_connect('activate') do |entry, event, user_data|
      @map.name = entry.text
      map_header.set_title(@map.name)
      map_header_stack.set_visible_child(map_header_eventbox)
    end
    map_header_edit.signal_connect('focus-out-event') do |entry, event, user_data|
      map_header_stack.set_visible_child(map_header_eventbox)
    end
    toggle_map_details_button.signal_connect('toggled') do |entry, event, user_data|
      if toggle_map_details_button.active?
        map_stack.set_visible_child(map_details)
      else
        map_stack.set_visible_child(map_scroll)
      end
    end
    ### MAP CANVAS ###
    map_canvas.add_events(:button_press_mask) # Enable mouse events on map
    map_canvas.signal_connect('draw') do |map_canvas, ctx|
      draw_map(ctx)
    end
    map_canvas.signal_connect('button-press-event') do |map_canvas, event, user_data|
      map_canvas_mouse_click(map_canvas, event)
    end
    ### MAP DETAILS ###
    text_map_description.buffer.signal_connect('changed') do |textbuffer, event, user_data|
      @map.description = textbuffer.text
    end
    ### NEW MAP ###
    button_new_map.signal_connect('button-press-event') do |button, event, user_data|
      update_map_config()
      new_map()
    end
    button_new_map_cancel.signal_connect('button-press-event') do |button, event, user_data|
      map_stack.set_visible_child(map_scroll)
    end
  end

  def setup_map_menu
    menu = map_menu_button.popup
    menu.children.select{|m|m.label=='gtk-new'}[0].signal_connect('activate') do |menu_item, event, user_data|
      update_new_map_ui()
      map_stack.set_visible_child(new_map_options_scroll)
    end
    menu.children.select{|m|m.label=='New (Same Settings)'}[0].signal_connect('activate') do |menu_item, event, user_data|
      new_map()
    end
    menu.children.select{|m|m.label=='gtk-open'}[0].signal_connect('activate') do |menu_item, event, user_data|
      map = map_dialog(:open)
      load_map(map) if map.kind_of? Map
    end
    menu.children.select{|m|m.label=='gtk-save'}[0].signal_connect('activate') do |menu_item, event, user_data|
      if @map.save()
        popup = Gtk::MessageDialog.new(parent: self,
                                       flags: Gtk::DialogFlags::DESTROY_WITH_PARENT,
                                       buttons: :ok,
                                       message: "Map saved to #{@map.file}")
        popup.run
        popup.destroy
      else
        popup = Gtk::MessageDialog.new(parent: self,
                                       flags: Gtk::DialogFlags::DESTROY_WITH_PARENT,
                                       type: :error,
                                       buttons: :ok,
                                       message: "Failed to save map to #{@map.file}")
        popup.run
        popup.destroy
      end
    end
    menu.children.select{|m|m.label=='gtk-save-as'}[0].signal_connect('activate') do |menu_item, event, user_data|
      map_dialog(:save, @map)
    end
  end

  def map_dialog(mode, map = nil)
    dialog = Gtk::FileChooserNative.new("#{mode.to_s.capitalize} Map Yaml File", self, mode)
    filter = Gtk::FileFilter.new()
    filter.name = "YAML files"
    filter.add_pattern("*.yaml")
    dialog.add_filter(filter)
    dialog.add_shortcut_folder("#{Configuration.project_path}/data/maps")
    dialog.filename = map.file unless map.file.nil?
    response = dialog.run()
    case response
    when Gtk::ResponseType::ACCEPT
      begin
        case mode
        when :open
          map = Map.load(dialog.filename)
        when :save
          map.save(dialog.filename)
        end
      rescue StandardError => e
        log_error e.to_s
        log_error "Could not #{mode.to_s} map file: #{dialog.filename}"
        map = nil
      end
    end
    return map
  end

  def update_new_map_ui()
    new_map_option_party_members.value = $configuration['party_members'].clone
    new_map_option_party_level.value = $configuration['party_level'].clone
  end

  def update_map_config()
    $configuration['party_members'] = new_map_option_party_members.value.to_i
    $configuration['party_level'] = new_map_option_party_level.value.to_i
  end

  def new_map()
    load_map()
  end

  def load_map(map = nil)
    map = MapGenerator.generate_map() if map.nil?
    @map = map
    @selected_map_object = nil
    display_map_details(map)
    load_info_panel()
    map_canvas.queue_draw()
    map_stack.set_visible_child(map_scroll)
  end

  def display_map_details(map = @map)
    map_header.title = map.name
    text_map_description.buffer.text = map.description
  end

  def draw_map(ctx, map = @map)
    return if map.nil?
    draw_map_background(ctx)
    draw_map_squares(ctx, map)
    draw_grid(ctx, map.size, map.size)
    draw_empty_squares(ctx, map)
    draw_walls(ctx, map)
    draw_doors(ctx, map)
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

  def draw_doors(ctx, map = @map)
    map.doors.each { |door|
      draw_door(ctx, door)
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
    set_color(ctx, 'lavender') if @selected_map_object == square.map_object
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

  def draw_door(ctx, door)
    pos = door.abs_map_pos()
    base_px = pos[:x] * SQUARE_PIXELS
    base_py = pos[:y] * SQUARE_PIXELS
    depth = DOOR_PIXELS
    length = (door.width * SQUARE_PIXELS) * DOOR_LENGTH_RATIO
    length_offset = ((door.width * SQUARE_PIXELS) * (1 - DOOR_LENGTH_RATIO)) / 2
    depth_offset = depth / 2
    case door.facing
    when :north, :south
      rect_start_x = base_px + depth_offset + 1
      rect_start_y = base_py - depth_offset
      rect_width = length
      rect_height = depth
    when :east, :west
      rect_start_x = base_px - length_offset + 1
      rect_start_y = base_py + length_offset
      rect_width = depth
      rect_height = length
    else
      raise "Door direction not allowed: #{direction}"
    end
    ctx.save()
    set_color(ctx, 'black')
    ctx.move_to(rect_start_x, rect_start_y)
    ctx.rectangle(rect_start_x, rect_start_y, rect_width, rect_height)
    ctx.stroke_preserve()
    set_color(ctx, 'white')
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

  def load_info_panel(map_object = @selected_map_object)
    @info_panel.destroy() unless @info_panel.nil?
    @info_panel = DungeonGeneratorInfoPanel.new(map_object)
    info_pane.pack_start(@info_panel, expand: true, fill: true)
  end

  def map_canvas_mouse_click(map_canvas, event, map = @map)
    selected_map_coordinates = {x: event.x / SQUARE_PIXELS, y: event.y / SQUARE_PIXELS}
    selected_square = map.square(selected_map_coordinates)
    return false if selected_square.nil?
    selected_map_object = selected_square.map_object
    case event.button
    when Gdk::BUTTON_PRIMARY
      @selected_map_object = selected_map_object
      map_canvas.queue_draw()
      load_info_panel(selected_map_object)
    when Gdk::BUTTON_SECONDARY
    end
  end 
end

class DungeonGeneratorGui < Gtk::Application
  include DungeonGeneratorHelper
  
  def initialize()
    super('com.github.whitemage12380.dungeon_generator', Gio::ApplicationFlags::FLAGS_NONE)
    signal_connect :activate do |application|
      window = DungeonGeneratorWindow.new(application)
      window.set_wmclass "Dungeon Generator", "Dungeon Generator"
      window.icon_name = 'dungeon-generator'
      window.present
    end
  end
end