# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

unless file_loaded?(__FILE__)
  extension = SketchupExtension.new('Profile Measure', 'profile_measure/main')
  extension.description = 'Reports profile dimensions, section totals, cut-aware stock estimates and direct PDF exports.'
  extension.version = '0.1.5'
  extension.creator = 'Codex'
  extension.copyright = '2026'
  Sketchup.register_extension(extension, true)
  file_loaded(__FILE__)
end

