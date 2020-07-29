#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh

  # debug = Sketchup.read_default(PLUGIN_ID, 'DebugMode', false)
  debug = false
  if debug
    PATH_SOLUTION = File.expand_path( File.join(PATH_ROOT, '..') )
    PATH_PROFILE_TESTS = File.join(PATH_SOLUTION, 'profiling')

    # Load profiling tests.
    filter = File.join(PATH_PROFILE_TESTS, 'PR_*.rb')
    Dir.glob(filter).each { |file|
      begin
        require file
      rescue LoadError => error
        puts error.message
      end
    }

    # Build debug menus and toolbars.
    unless file_loaded?('B2M::Debug::UI')
      menu = UI.menu('Plugins').add_submenu("#{PLUGIN_NAME} Debug Tools")

      # Generate menus for profiling tests.
      menu_profile = menu.add_submenu("Profile…")
      menu_profile.add_item("List Profile Tests") {
        raise NotImplementedError
      }
      menu_profile.add_separator
      if defined?(Profiling)
        SpeedUp.build_menus(menu_profile, Profiling)
      end

      file_loaded('B2M::Debug::UI')
    end
  end

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::BitmapToMesh.reload
  #
  # @return [Integer] Number of files reloaded.
  # @since 1.0.0
  def self.reload
    original_verbose = $VERBOSE
    $VERBOSE = nil
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?(PATH) && File.exist?(PATH)
      pattern = File.join(PATH, '**/*.rb')
      x = Dir.glob(pattern).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module
