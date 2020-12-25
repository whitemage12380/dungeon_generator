require 'gtk3'
require 'fileutils'
require_relative 'configuration'
require_relative 'map_generator'
require_relative 'dungeon_generator_gtk_helper'

class DungeonGeneratorContent < Gtk::Box
  include DungeonGeneratorGtkHelper

  def initialize(content, section)
    super(:vertical, 4)
    display_content(content, section)
  end

  def display_content(content, section)
    case section
    when :hazards, :obstacles
      label = Gtk::Label.new(content)
      pack_end(label)
    when :monsters
      monster_group = content.monster_groups.first
      labels = monster_group_labels(content.monster_groups[0])
      if content.monster_groups.count == 2
        relationship_label = Gtk::Label.new()
        relationship_label.markup = "<b>#{content.relationship}</b>"
        labels << relationship_label
        labels.concat(monster_group_labels(content.monster_groups[1]))
      end
      labels.each { |l| pack_start(l) }
    when :traps
      trap = content
      label_trigger = Gtk::Label.new()
      label_severity = Gtk::Label.new()
      label_effectiveness = Gtk::Label.new()
      label_damage = Gtk::Label.new()
      label_effect = Gtk::Label.new()
      label_severity.text = trap.severity
      label_effectiveness.text = "DC #{trap.dc} or +#{trap.attack} to hit"
      label_damage.text = "#{trap.damage} damage"
      label_trigger.markup = "<b>Trigger:</b> #{trap.trigger}"
      label_effect.markup = "<b>Effect:</b> #{trap.effect}"
      pack_start(label_severity)
      pack_start(label_effectiveness)
      pack_start(label_damage)
      pack_start(label_trigger)
      pack_start(label_effect)
    when :tricks
      trick = content
      label_object = Gtk::Label.new(trick.object)
      label_effect = Gtk::Label.new()
      label_effect.markup = "<b>Effect:</b> #{trick.effect}"
      pack_start(label_object)
      pack_start(label_effect)
    when :treasure
      if content.kind_of? TreasureStash or content.size == 1
        treasure_stash = (content.kind_of? TreasureStash) ? content : content.first
        treasure_stash_labels(treasure_stash).each { |l| pack_start(l)}
      end
    when :features
      content.sort_by { |c| c.to_s }.collect { |f| Gtk::Label.new(f.to_s)}
        .each { |l| pack_start(l)}
    when :doors
      label = Gtk::Label.new(content[:door].exit_string(content[:starting_connector]))
      pack_start(label)
    end
    children.select{ |c| c.kind_of? Gtk::Label }.each { |c|
      c.xalign = 0
      c.set_line_wrap(true)
    }
  end

  def monster_group_labels(monster_group)
    labels = Array.new()
    monster_group.uniq { |m| m.name }.each { |m|
      monster_count = monster_group.count { |n| n.name == m.name}
      label = Gtk::Label.new((monster_count > 1) ? "#{m.name} x#{monster_count}" : m.name)
      label.tooltip_text = "#{m.book} (p. #{m.page})"
      labels << label
    }
    xp_label = Gtk::Label.new()
    xp_label.markup = "<b>XP:</b> #{monster_group.xp} (#{xp_threshold(monster_group.xp).to_s.capitalize})"
    labels << xp_label
    unless monster_group.motivation.nil?
      motivation = Gtk::Label.new()
      motivation.markup = "<b>Motivation:</b> #{monster_group.motivation}"
      labels << motivation
    end
    return labels
  end

  def treasure_stash_labels(treasure_stash)
    labels = Array.new
    labels.concat treasure_stash.items.sort_by { |i| i.name }.collect { |i| Gtk::Label.new(i.name)}
    labels.concat treasure_stash.valuables.sort_by { |i| [i.worth, i.name] }.collect { |i|
      Gtk::Label.new("#{i.name} (#{i.worth} gp)")
    }
    labels.concat treasure_stash.coins.to_a.sort_by { |c| ['pp', 'gp', 'ep', 'sp', 'cp'].index(c[0]) }.collect { |c|
      Gtk::Label.new("#{c[1]} #{c[0]}")
    }
    return labels
  end
end

class DungeonGeneratorContentSection < Gtk::Expander
  include DungeonGeneratorGtkHelper

  def initialize(map_object, section)
    super(section.to_s.capitalize)
    display_contents(map_object, section)
    set_expanded(true)
  end

  def display_contents(map_object, section)
    return if map_object.nil? or map_object.contents.nil? or map_object.contents[section].nil? or map_object.contents[section].empty?
    if @section_container.nil?
      @section_container = DungeonGeneratorInfoPanelBox.new()
      add(@section_container)
    else
      @section_container.clean()
    end
    map_object.contents[section].each { |c|
      entry = DungeonGeneratorContent.new(c, section)
      @section_container.pack_end(entry)
    }
  end
end

class DungeonGeneratorDoorSection < Gtk::Expander
  include DungeonGeneratorGtkHelper

  def initialize(map_object)
    super("Doors")
    display_doors(map_object)
    set_expanded(true)
  end

  def display_doors(map_object)
    return if map_object.nil? or ((map_object.doors.nil? or map_object.doors.empty?) and map_object.starting_connector_type != "door")
    if @section_container.nil?
      @section_container = DungeonGeneratorInfoPanelBox.new()
      add(@section_container)
    else
      @section_container.clean()
    end
    if map_object.starting_connector_type == "door"
      @section_container.pack_start(DungeonGeneratorContent.new({door: map_object.starting_connector, starting_connector: true}, :doors))
    end
    map_object.doors.each { |door|
      @section_container.pack_start(DungeonGeneratorContent.new({door: door, starting_connector: false}, :doors))
    }
  end
end

class DungeonGeneratorInfoPanelBox < Gtk::Box
  include DungeonGeneratorGtkHelper

  def initialize()
    super(:vertical, 8)
    set_margin_left(30)
    set_margin_top(8)
    set_margin_bottom(8)
  end

  def clean()
    children.each { |s| remove_child(s) }
  end
end

class DungeonGeneratorPaneHeader < Gtk::HeaderBar
  include DungeonGeneratorHelper

  def initialize(title = nil, subtitle = nil)
    super()
    self.title = title
    self.subtitle = subtitle
  end
end

class DungeonGeneratorInfoPanel < Gtk::Box
  include DungeonGeneratorGtkHelper
  type_register

  CONTENT_SECTION_NAMES = [:hazards, :monsters, :obstacles, :traps, :treasure, :tricks, :features]
  class << self
    def init
      set_template(resource: "/ui/dungeon_generator_info_panel.ui")
      bind_template_child('info_panel_header')
      bind_template_child('info_panel_header_stack')
      bind_template_child('info_panel_header_edit')
      bind_template_child('info_panel_header_eventbox')
      bind_template_child('info_panel_content')
      bind_template_child('text_description')
      #### TOOLBAR ###
      bind_template_child('map_object_generate_contents')
      bind_template_child('map_object_generate_name')
    end
  end

  def initialize(map_object = nil)
    super()
    display_map_object(map_object)
    info_panel_header_eventbox.add_events(:button_press_mask)
    text_description.buffer.signal_connect('changed') do |textbuffer, event, user_data|
      map_object.description = textbuffer.text
    end
    map_object_generate_contents.signal_connect('clicked') do |button, event, user_data|
      randomize_chamber_contents(map_object)
    end
    map_object_generate_name.signal_connect('clicked') do |button, event, user_data|
      info_panel_header_stack.set_visible_child(info_panel_header_eventbox)
      randomize_chamber_purpose(map_object)
    end
    info_panel_header_eventbox.signal_connect('button-press-event') do |eventbox, event, user_data|
      info_panel_header_edit.set_text(info_panel_header.subtitle)
      info_panel_header_stack.set_visible_child(info_panel_header_edit)
      info_panel_header_edit.grab_focus()
    end
    info_panel_header_edit.signal_connect('activate') do |entry, event, user_data|
      map_object.name = entry.text
      info_panel_header.set_subtitle(map_object.name)
      info_panel_header_stack.set_visible_child(info_panel_header_eventbox)
    end
  end

  def display_map_object(map_object = nil)
    if map_object.nil?
      info_panel_content.hide()
      return
    end
    @content_sections = CONTENT_SECTION_NAMES.map { |s| [s, nil]}.to_h if @content_sections.nil?
    info_panel_header.title = map_object.id_str
    info_panel_header.subtitle = map_object.name unless map_object.name == map_object.id_str
    text_description.buffer.text = map_object.description
    content_section_widgets.each { |s| info_panel_content.remove_child(s) }
    CONTENT_SECTION_NAMES.each { |type| display_map_object_content_section(map_object, type) }
    display_door_info(map_object)
    info_panel_content.show()
  end

  def display_map_object_content_section(map_object, type)
    if map_object.contents.nil? or map_object.contents[type].nil? or map_object.contents[type].empty?
      @content_sections[type].hide() unless @content_sections[type].nil?
      return
    end
    section_exists = @content_sections[type] ? true : false
    section = @content_sections[type] ? @content_sections[type] : DungeonGeneratorContentSection.new(map_object, type)
    if section_exists
      section.display_section(map_object, type)
    else
      info_panel_content.pack_start(section, padding: 0)
    end
    section.show_all()
  end

  def display_door_info(map_object)
    return unless (map_object.doors.any? { |door| not (door.style.nil? and door.state.nil?) }) or map_object.starting_connector_type == "door"
    if @door_section.nil?
      @door_section = DungeonGeneratorDoorSection.new(map_object)
      info_panel_content.pack_start(@door_section, padding: 0)
    else
      @door_section.display_doors(map_object)
    end
    @door_section.show_all()
  end

  def randomize_chamber_purpose(map_object)
    return unless map_object.kind_of? Chamber
    map_object.generate_purpose()
    info_panel_header.subtitle = map_object.name
    text_description.buffer.text = map_object.description
  end

  def randomize_chamber_contents(map_object)
    return unless map_object.kind_of? Chamber
    map_object.generate_contents()
    display_map_object(map_object)
  end

  def content_section_widgets
    info_panel_content.children.select { |c| c.kind_of? DungeonGeneratorContentSection }
  end
end

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
      #### MENU ###
      bind_template_child('menubar')
      bind_template_child('file_new')
      bind_template_child('file_open')
      bind_template_child('file_save')
      bind_template_child('file_save_as')
      bind_template_child('file_quit')
      #############
      bind_template_child('map_header')
      bind_template_child('map_header_stack')
      bind_template_child('map_header_edit')
      bind_template_child('map_header_eventbox')
      bind_template_child('map_canvas')
      bind_template_child('info_pane')
      bind_template_child('panes')
    end
  end

  def initialize(application, map = nil)
    super(application: application)
    setup_menubar()
    load_info_panel()
    load_map()

    map_header.title = @map.name
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

    map_canvas.add_events(:button_press_mask) # Enable mouse events on map
    map_canvas.signal_connect('draw') do |map_canvas, ctx|
      draw_map(ctx)
    end
    map_canvas.signal_connect('button-press-event') do |map_canvas, event, user_data|
      map_canvas_mouse_click(map_canvas, event)
    end
  end

  def setup_menubar
    file_new.signal_connect('activate') do |menu_item, event, user_data|
      load_map()
      load_info_panel()
      map_canvas.queue_draw()
    end
    file_open.signal_connect('activate') do |menu_item, event, user_data|
      map = map_dialog(:open)
      if map.kind_of? Map
        load_map(map)
        load_info_panel()
        map_canvas.queue_draw()
      end
    end
    file_save_as.signal_connect('activate') do |menu_item, event, user_data|
      map_dialog(:save, @map)
    end
  end

  def map_dialog(mode, map = nil)
    dialog = Gtk::FileChooserNative.new("#{mode.to_s.capitalize} Map Yaml File", self, mode)
    filter = Gtk::FileFilter.new()
    filter.add_pattern("*.yaml")
    dialog.add_filter(filter)
    dialog.add_shortcut_folder("#{Configuration.project_path}/data/maps")
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

  def load_map(map = nil)
    map = MapGenerator.generate_map() if map.nil?
    @map = map
    @selected_map_object = nil
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