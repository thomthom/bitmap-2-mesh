#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh

  # Minimum version of SketchUp required to run the extension.
  MINIMUM_SKETCHUP_VERSION = 14

  if Sketchup.version.to_i < MINIMUM_SKETCHUP_VERSION

    # Not localized because we don't want the Translator and related
    # dependencies to be forced to be compatible with older SketchUp versions.
    version_name = "20#{MINIMUM_SKETCHUP_VERSION}"
    message = "#{PLUGIN_NAME} require SketchUp #{version_name} or newer."
    messagebox_open = false # Needed to avoid opening multiple message boxes.
    # Defer with a timer in order to let SketchUp fully load before displaying
    # modal dialog boxes.
    UI.start_timer(0, false) {
      unless messagebox_open
        messagebox_open = true
        UI.messagebox(message)
        # Must defer the disabling of the extension as well otherwise the
        # setting won't be saved. I assume SketchUp save this setting after it
        # loads the extension.
        if @extension.respond_to?(:uncheck)
          @extension.uncheck
        end
      end
    }

  else # Sketchup.version

    require 'tt_bitmap2mesh/settings'
    require 'tt_bitmap2mesh/error_reporter/error_reporter'

    server = if Settings.local_error_server?
      "sketchup.thomthom.local"
    else
      "sketchup.thomthom.net"
    end

    config = {
      :extension_id => PLUGIN_ID,
      :extension    => @extension,
      :server       => "http://#{server}/api/v1/extension/report_error",
      :support_url  => "https://extensions.sketchup.com/content/bitmap-mesh",
      :debug        => Settings.debug_mode?,
      :test         => Settings.test_mode?
    }
    ERROR_REPORTER = ErrorReporter.new(config)

    begin
      require 'tt_bitmap2mesh/core'
    rescue Exception => error
      ERROR_REPORTER.handle(error)
    end

  end # if Sketchup.version

end # module
