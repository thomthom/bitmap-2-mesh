#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh

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
