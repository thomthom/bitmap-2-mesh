#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/image/image_rep'
require 'tt_bitmap2mesh/image/bmp'
require 'tt_bitmap2mesh/image/dib'


module TT::Plugins::BitmapToMesh
  # Generic interface that delegate to either the newer ImageRep or the
  # old DIB interface. This done to keep compatibility with pre-SU2018
  # versions.
  class Bitmap

    FORCE_LEGACY = false # For testing the old interface in newer SU versions.

    def self.from_image(image)
      if image.respond_to?(:image_rep) && !FORCE_LEGACY
        return self.new(image.image_rep)
      end
      dib = self.temp_image_file(image) { |temp_file|
        BMP.new(temp_file)
      }
      self.new(dib)
    end

    def self.temp_image_file(image, &block)
      temp_path = File.expand_path(TT::System.temp_path)
      temp_file = File.join(temp_path, 'TT_BMP2Mesh.bmp')
      tw = Sketchup.create_texture_writer
      tw.load(image)
      tw.write(image, temp_file)
      begin
        result = block.call(temp_file)
      ensure
        File.delete(temp_file) if File.exist?(temp_file)
      end
      result
    end

    def initialize(source)
      if source.is_a?(String)
        if defined?(Sketchup::ImageRep) && !FORCE_LEGACY
          @instance = ImageRep.new(source)
        else
          @instance = BMP.new(source)
        end
      elsif defined?(Sketchup::ImageRep) && source.is_a?(Sketchup::ImageRep) && !FORCE_LEGACY
        @instance = ImageRep.new(source)
      elsif source.is_a?(BMP)
        @instance = source
      else
        raise TypeError
      end
    end

    def create_material(model, name = "b2m_image")
      material = model.materials.add(name)
      temp_file { |temp_file|
        material.texture = temp_file
      }
      material
    end

    def provider
      @instance.class
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
      index = (width * y) + x
      data[index]
    end

    def temp_file(&block)
      temp_path = File.expand_path(TT::System.temp_path)
      temp_filename = File.join(temp_path, 'TT_BMP2Mesh.bmp')
      @instance.save(temp_filename)
      begin
        result = block.call(temp_filename)
      ensure
        File.delete(temp_filename) if File.exist?(temp_filename)
      end
      result
    end

  end # module
end # module
