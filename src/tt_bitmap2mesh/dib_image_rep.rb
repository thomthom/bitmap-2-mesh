#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BitmapToMesh
  # Interface to expose ImageRep functionality in similar fashion to GL_DIB.
  class DIBImageRep

    def initialize(source)
      if source.is_a?(String)
        @image_rep = Sketchup::ImageRep.new(source)
      elsif defined?(Sketchup::ImageRep) && source.is_a?(Sketchup::ImageRep)
        @image_rep = source
      end
      # The rows from ImageRep needs to be reversed in order to be compatible
      # with GL_DIB.
      @data = @image_rep.colors.each_slice(width).to_a.reverse.flatten.map(&:to_a)
    end

    def pixels
      @image_rep.width * @image_rep.height
    end

    def data
      @data
    end

    def width
      @image_rep.width
    end

    def height
      @image_rep.height
    end

  end # class
end # module
