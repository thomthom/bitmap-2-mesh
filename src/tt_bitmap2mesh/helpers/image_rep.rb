#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh
  module ImageRepHelper

    IS_WIN = Sketchup.platform == :platform_win

    def self.colors_to_image_rep(width, height, colors)
      row_padding = 0
      bits_per_pixel = 32
      pixel_data = self.colors_to_32bit_bytes(colors)
      image_rep = Sketchup::ImageRep.new
      image_rep.set_data(width, height, bits_per_pixel, row_padding, pixel_data)
      image_rep
    end

    # From C API documentation on SUColorOrder
    #
    # > SketchUpAPI expects the channels to be in different orders on
    # > Windows vs. Mac OS. Bitmap data is exposed in BGRA and RGBA byte
    # > orders on Windows and Mac OS, respectively.
    def self.color_to_32bit(color)
      r, g, b, a = color.to_a
      IS_WIN ? [b, g, r, a] : [r, g, b, a]
    end

    def self.colors_to_32bit_bytes(colors)
      colors.map { |color| self.color_to_32bit(color) }.flatten.pack('C*')
    end

    def self.color_to_24bit(color)
      self.color_to_32bit(color)[0, 3]
    end

    def self.colors_to_24bit_bytes(colors)
      colors.map { |color| self.color_to_24bit(color) }.flatten.pack('C*')
    end

  end # module
end # module
