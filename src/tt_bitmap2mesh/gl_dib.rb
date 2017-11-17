#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BitmapToMesh

  # :data must be a hash where the key is a colour and the values are array of
  # points. This way the image data is drawn in the most efficient manner using
  # the SketchUp API available.
  module GL_DIB
    attr_accessor(:width, :height, :data)

    def initialize(filename)
      @data = read_image(filename)
    end

    def pixels
      @width * @height
    end

  end # module GL_DIB

end # module
