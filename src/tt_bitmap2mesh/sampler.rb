#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/draggable'
require 'tt_bitmap2mesh/text'


module TT::Plugins::BitmapToMesh
  class Sampler

    # @param [Bitmap] bitmap
    # @param [Integer] max_sample_size
    # @return [nil]
    def sample(bitmap, max_sample_size, &block)
      max_image_size = [bitmap.width, bitmap.height].max
      scale_down = max_sample_size.to_f / max_image_size.to_f
      scaled_width = (bitmap.width * scale_down).round
      scaled_height = (bitmap.height * scale_down).round
      scale_up = 1.0 / scale_down
      scaled_width.times { |scaled_x|
        scaled_height.times { |scaled_y|
          x = (scaled_x * scale_up).round
          y = (scaled_y * scale_up).round
          color = bitmap[x, y]
          block.call(color, scaled_x, scaled_y)
        }
      }
      nil
    end

    # @param [Bitmap] bitmap
    # @param [Integer] max_sample_size
    # @return [nil]
    def sample2(bitmap, max_sample_size, &block)
      max_image_size = [bitmap.width, bitmap.height].max
      scale_down = max_sample_size.to_f / max_image_size.to_f
      scaled_width = (bitmap.width * scale_down).round
      scaled_height = (bitmap.height * scale_down).round
      scale_up = 1.0 / scale_down
      scaled_height.times { |scaled_y|
        scaled_width.times { |scaled_x|
          x = (scaled_x * scale_up).round
          y = (scaled_y * scale_up).round
          color = bitmap[x, y]
          block.call(color, scaled_x, scaled_y)
        }
      }
      nil
    end

  end # class
end # module
