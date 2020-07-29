#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'fileutils'
require 'json'


module TT::Plugins::BitmapToMesh
module Tests
  module TestUtilities

    # Debug method to reload this utility module.
    def self.reload
      load __FILE__ # rubocop:disable SketchupSuggestions/FileEncoding
    end


    # @param [String] relative_path
    # @return [String]
    def project_file(relative_path)
      project_path = File.expand_path('../..', __dir__)
      File.join(project_path, relative_path)
    end

    # @param [String] path
    # @return [String]
    def test_file(path)
      unless File.exist?(path)
        base_path = File.dirname(caller_locations(1, 1).first.path)
        path = File.join(base_path, path)
      end
      raise "file not found: #{file}" unless File.exist?(path)
      path
    end

    # @param [String] path
    # @return [Sketchup::Model]
    def open_model(path)
      file = test_file(path)
      Sketchup.active_model.close(true)
      Sketchup.open_file(file)
      Sketchup.active_model
    end

  end # module
end
end
