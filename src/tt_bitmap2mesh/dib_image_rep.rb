#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BitmapToMesh
  class DIBImageRep

    def initialize(source)
      if source.is_a?(String)
        @image_rep = Sketchup::ImageRep.new(source)
      elsif defined?(Sketchup::ImageRep) && source.is_a?(Sketchup::ImageRep)
        @image_rep = source
      end
      @data = @image_rep.colors.map(&:to_a)
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
