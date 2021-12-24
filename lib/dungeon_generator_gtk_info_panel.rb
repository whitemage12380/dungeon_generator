require 'gtk3'
require 'fileutils'
require_relative 'configuration'
require_relative 'map_generator'
require_relative 'dungeon_generator_gtk_helper'


class DungeonGeneratorContentSectionMenu < Gtk::PopoverMenu
  include DungeonGeneratorGtkHelper
  type_register

  CONTENT_SECTION_NAMES = [:hazards, :monsters, :obstacles, :traps, :treasure, :tricks, :features]
  class << self
    def init
      set_template(resource: "/ui/dungeon_generator_content_section_menu.ui")
      bind_template_child('content_section_menu_randomize')
      bind_template_child('content_section_menu_delete')
    end
  end

  def initialize(map_object, section)
    super()
    action_randomize = Gio::SimpleAction.new("randomize_section")
    action_delete = Gio::SimpleAction.new("delete_section")
    action_randomize.signal_connect("activate") do |_action, parameter|
      puts "randomize"
    end
  end
end

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

#class DungeonGeneratorContentSectionMenu < 

class DungeonGeneratorContentSection < Gtk::Expander
  include DungeonGeneratorGtkHelper

  def initialize(map_object, section)
    super(section.to_s.capitalize)
    add_events(:button_press_mask)
    signal_connect('button-press-event') do |section, event, user_data|
      if event.button == 3
        popover = DungeonGeneratorContentSectionMenu.new(map_object, section)
        #popover = Gtk::Popover.new()
        #popover.set_relative_to self
        popover.relative_to = self
        #popover.show
        popover.popup()
      else
        false
      end
    end
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
      unless info_panel_header.subtitle.nil?
        info_panel_header_edit.set_text(info_panel_header.subtitle)
        info_panel_header_stack.set_visible_child(info_panel_header_edit)
        info_panel_header_edit.grab_focus()
      end
    end
    info_panel_header_edit.signal_connect('activate') do |entry, event, user_data|
      map_object.name = entry.text
      info_panel_header.set_subtitle(map_object.name)
      info_panel_header_stack.set_visible_child(info_panel_header_eventbox)
    end
    info_panel_header_edit.signal_connect('focus-out-event') do |entry, event, user_data|
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