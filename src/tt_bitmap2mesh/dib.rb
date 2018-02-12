#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/dib_image_rep'
require 'tt_bitmap2mesh/gl_bmp'
require 'tt_bitmap2mesh/gl_dib'


module TT::Plugins::BitmapToMesh
  # Generic interface that delegate to either the newer DIBImageRep or the old
  # GL_DIB interface. This done to keep compatibility with pre-SU2018 versions.
  class DIB

    def self.from_image(image)
      if image.respond_to?(:image_rep)
        return self.new(image.image_rep)
      end
      temp_path = File.expand_path(TT::System.temp_path)
      temp_file = File.join(temp_path, 'TT_BMP2Mesh.bmp')
      tw = Sketchup.create_texture_writer
      tw.load(image)
      tw.write(image, temp_file)
      dib = GL_BMP.new(temp_file)
      File.delete(temp_file)
      self.new(dib)
    end

    def initialize(source)
      if source.is_a?(String)
        if defined?(Sketchup::ImageRep)
          @instance = DIBImageRep.new(source)
        else
          @instance = GL_BMP.new(source)
        end
      elsif defined?(Sketchup::ImageRep) && source.is_a?(Sketchup::ImageRep)
        @instance = DIBImageRep.new(source)
      elsif source.is_a?(GL_DIB)
        @instance = source
      else
        raise TypeError
      end
    end

    def pixels
      @instance.pixels
    end

    def data
      @instance.data
    end

    def width
      @instance.width
    end

    def height
      @instance.height
    end

    def [](x, y)
      y2 = height - 1 - y
      index = (width * y2) + x
      data[index]
    end

  end # module
end # module
