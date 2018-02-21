#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BitmapToMesh
  module Settings

    def self.read(key, default = nil)
      Sketchup.read_default(PLUGIN_ID, key, default)
    end

    def self.write(key, value)
      Sketchup.write_default(PLUGIN_ID, key, value)
    end


    # TT::Plugins::BitmapToMesh::Settings.debug_mode = true
    @debug_mode = self.read("DebugMode", false)
    def self.debug_mode?
      @debug_mode
    end
    def self.debug_mode=(boolean)
      @debug_mode = boolean ? true : false
      self.write("DebugMode", @debug_mode)
    end


    # TT::Plugins::BitmapToMesh::Settings.local_error_server = true
    @local_error_server = self.read("LocalErrorServer", false)
    def self.local_error_server?
      @local_error_server
    end
    def self.local_error_server=(boolean)
      @local_error_server = boolean ? true : false
      self.write("LocalErrorServer", @local_error_server)
    end

  end # module Settings
end # module TT::Plugins::BitmapToMesh
