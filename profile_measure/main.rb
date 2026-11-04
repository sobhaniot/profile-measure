# frozen_string_literal: true

require 'sketchup.rb'
require_relative 'report'

module CodexProfileMeasure
  extend self

  DICTIONARY = 'CodexProfileMeasure'.freeze
  LABEL_KEY = 'generated_label'.freeze

  def supported?(entity)
    entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
  end

  # Return sorted local dimensions after applying instance scale. The longest
  # dimension is treated as the profile length.
  def dimensions(entity)
    bounds = entity.definition.bounds
    transform = entity.transformation
    sizes = [
      bounds.width * transform.xaxis.length,
      bounds.height * transform.yaxis.length,
      bounds.depth * transform.zaxis.length
    ].map(&:to_f).sort.reverse

    sizes
  end

  def formatted(value)
    Sketchup.format_length(value)
  end

  def text_point(bounds)
    Geom::Point3d.new(bounds.center.x, bounds.center.y, bounds.max.z)
  end

  def offset_for(bounds)
    extent = [bounds.width, bounds.height, bounds.depth].map(&:to_f).max
    distance = [extent * 0.12, 1.0].max
    Geom::Vector3d.new(distance, 0, distance)
  end

  def scaled_vector(vector, factor)
    Geom::Vector3d.new(vector.x * factor, vector.y * factor, vector.z * factor)
  end

  def clear_generated_labels(entities)
    labels = entities.grep(Sketchup::Text).select do |text|
      text.get_attribute(DICTIONARY, LABEL_KEY, false)
    end
    entities.erase_entities(labels) unless labels.empty?
  end

  def create_attached_label(entities, entity, label, anchor, vector)
    text = entities.add_text(label, anchor, vector)
    text.set_attribute(DICTIONARY, LABEL_KEY, true)

    begin
      path = Sketchup::InstancePath.new([entity])
      local_anchor = entity.transformation.inverse * anchor
      text.attached_to = [path, local_anchor]
    rescue StandardError
      # Keep a usable, fixed-position label if SketchUp cannot attach the note.
    end

    text
  end

  def add_labels
    model = Sketchup.active_model
    entities = model.active_entities
    operation_started = false
    selection = model.selection.to_a.select { |entity| supported?(entity) }

    if selection.empty?
      UI.messagebox('ابتدا یک یا چند پروفیل را به‌صورت Group یا Component انتخاب کنید.')
      return
    end

    rows = selection.map do |entity|
      length, width, height = dimensions(entity)
      [entity, length, width, height]
    end
    total_length = rows.inject(0.0) { |sum, row| sum + row[1] }

    model.start_operation('Profile Measure - dimensions and total', true)
    operation_started = true
    clear_generated_labels(entities)

    rows.each do |entity, length, width, height|
      label = "L: #{formatted(length)}  |  W: #{formatted(width)}  |  H: #{formatted(height)}"
      bounds = entity.bounds
      create_attached_label(entities, entity, label, text_point(bounds), offset_for(bounds))
    end

    overall = Geom::BoundingBox.new
    rows.each { |row| overall.add(row[0].bounds) }
    summary = "TOTAL L: #{formatted(total_length)} (#{rows.length} profiles)"
    summary_point = Geom::Point3d.new(overall.max.x, overall.max.y, overall.max.z)
    summary_text = entities.add_text(summary, summary_point, scaled_vector(offset_for(overall), 1.5))
    summary_text.set_attribute(DICTIONARY, LABEL_KEY, true)

    model.commit_operation
    operation_started = false
    model.active_view.invalidate

    UI.messagebox("تعداد پروفیل‌ها: #{rows.length}\nجمع طول: #{formatted(total_length)}")
  rescue StandardError => error
    model.abort_operation if operation_started && model
    UI.messagebox("خطا هنگام درج اندازه‌ها:\n#{error.message}")
  end

  def clear_labels
    model = Sketchup.active_model
    entities = model.active_entities
    operation_started = false
    model.start_operation('Profile Measure - clear labels', true)
    operation_started = true
    clear_generated_labels(entities)
    model.commit_operation
    operation_started = false
    model.active_view.invalidate
  rescue StandardError => error
    model.abort_operation if operation_started && model
    UI.messagebox("خطا هنگام پاک‌کردن برچسب‌ها:\n#{error.message}")
  end

  unless file_loaded?(__FILE__)
    menu = UI.menu('Extensions').add_submenu('Profile Measure')
    menu.add_item('گزارش کامل ابعاد پروفیل‌ها') { Report.show }
    menu.add_separator
    menu.add_item('درج ابعاد و جمع طول انتخاب‌ها') { add_labels }
    menu.add_item('پاک‌کردن برچسب‌های افزونه') { clear_labels }

    UI.add_context_menu_handler do |context_menu|
      has_profile_selection = Sketchup.active_model.selection.any? { |entity| supported?(entity) }
      if has_profile_selection
        context_menu.add_item('گزارش کامل ابعاد پروفیل‌ها') { Report.show }
        context_menu.add_separator
        context_menu.add_item('درج ابعاد و جمع طول پروفیل‌ها') { add_labels }
        context_menu.add_item('پاک‌کردن برچسب‌های Profile Measure') { clear_labels }
      end
    end

    icon_dir = File.join(__dir__, 'icons')
    command = UI::Command.new('گزارش ابعاد پروفیل‌ها') { Report.show }
    command.small_icon = File.join(icon_dir, 'profile_measure_24.png')
    command.large_icon = File.join(icon_dir, 'profile_measure_32.png')
    command.tooltip = 'فهرست ابعاد، دسته‌بندی و گزارش PDF برای پروفیل‌های مدل'
    command.status_bar_text = 'گزارش ابعاد همهٔ پروفیل‌های مدل را باز می‌کند.'

    @toolbar = UI::Toolbar.new('Profile Measure')
    @toolbar.add_item(command)
    last_toolbar_state = @toolbar.get_last_state
    @toolbar.restore
    @toolbar.show if last_toolbar_state == TB_NEVER_SHOWN

    file_loaded(__FILE__)
  end
end
