#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/image/color'


module TT::Plugins::BitmapToMesh
  class Color < Sketchup::Color

    def is_greyscale?
      red == green && green == blue
    end

    def luminance
      return red if is_greyscale?
      # Colorimetric conversion to greyscale.
      # Original:
      # http://forums.sketchucation.com/viewtopic.php?t=12368#p88865
      # (red * 0.3) + (green * 0.59) + (blue * 0.11)
      # Current: https://stackoverflow.com/a/596243/486990
      #  => https://www.w3.org/TR/AERT/#color-contrast
      ((red * 299) + (green * 587) + (blue * 114)) / 1000
    end

  end
end # module
